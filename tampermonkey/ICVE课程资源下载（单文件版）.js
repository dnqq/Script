// ==UserScript==
// @name         ICVE课程资源下载（单文件版）
// @namespace    http://tampermonkey.net/
// @version      1.1
// @description  精准下载当前课程页面的单个文件
// @author       YourName
// @match        *://zyk.icve.com.cn/icve-study/coursePreview/courseware?*
// @grant        GM_xmlhttpRequest
// @grant        GM_addStyle
// @grant        GM_notification
// @connect      icve.com.cn
// @license      MIT
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    const API_ENDPOINT = '/prod-api/teacher/courseContent/';
    const STATE_COLORS = {
        loading: '#17a2b8',
        ready: '#28a745',
        error: '#dc3545'
    };

    GM_addStyle(`
        .icve-download-btn {
            position: fixed !important;
            bottom: 20px !important;
            right: 20px !important;
            z-index: 9999 !important;
            padding: 12px 24px !important;
            border-radius: 8px !important;
            cursor: pointer !important;
            background: ${STATE_COLORS.loading};
            color: white !important;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
            font-family: system-ui, sans-serif;
            transition: background 0.3s;
        }
    `);

    class SingleFileDownloader {
        constructor() {
            this.courseId = this.getCourseId();
            this.fileInfo = null;
            this.initUI();
            this.loadFileInfo();
        }

        getCourseId() {
            const url = new URL(window.location.href);
            return url.searchParams.get('id');
        }

        getAuthToken() {
            const cookies = document.cookie.split(';');
            const tokenCookie = cookies.find(c => c.trim().startsWith('Token='));
            return tokenCookie ? `Bearer ${tokenCookie.split('=')[1]}` : null;
        }

        sanitizeFilename(name) {
            return name.replace(/[\\/:*?"<>|]/g, '_')
                      .replace(/\s+/g, ' ')
                      .substring(0, 100)
                      .trim();
        }

        initUI() {
            this.downloadBtn = document.createElement('div');
            this.downloadBtn.className = 'icve-download-btn';
            this.downloadBtn.textContent = '检测文件中...';
            document.body.appendChild(this.downloadBtn);

            this.downloadBtn.onclick = () => this.downloadFile();
        }

        async loadFileInfo() {
            try {
                const response = await this.fetchCourseData();
                this.handleApiResponse(response);
            } catch (error) {
                this.showError('数据加载失败', error);
            }
        }

        fetchCourseData() {
            return new Promise((resolve, reject) => {
                if (!this.courseId) return reject('未找到课程ID');

                GM_xmlhttpRequest({
                    method: 'GET',
                    url: `https://zyk.icve.com.cn${API_ENDPOINT}${this.courseId}`,
                    headers: {
                        Authorization: this.getAuthToken()
                    },
                    onload: res => {
                        try {
                            const data = JSON.parse(res.responseText);
                            data.code === 200 ? resolve(data) : reject(data.msg);
                        } catch (e) {
                            reject('响应解析失败');
                        }
                    },
                    onerror: err => reject(err)
                });
            });
        }

        handleApiResponse(response) {
            const { data } = response;

            // 优先使用可下载的URL
            const downloadUrl = data.fileUrl || data.fileGenUrl;

            if (!downloadUrl) {
                throw new Error('未找到有效下载地址');
            }

            this.fileInfo = {
                name: this.sanitizeFilename(data.name),
                url: downloadUrl.startsWith('http')
                    ? downloadUrl
                    : `https://file.icve.com.cn${downloadUrl}`,
                type: data.fileType
            };

            this.downloadBtn.style.background = STATE_COLORS.ready;
            this.downloadBtn.textContent = `下载${this.fileInfo.type.toUpperCase()}文件`;
        }

        downloadFile() {
            if (!this.fileInfo) return;

            const filename = `${this.fileInfo.name}.${this.fileInfo.type}`;

            GM_xmlhttpRequest({
                method: 'GET',
                url: this.fileInfo.url,
                responseType: 'blob',
                headers: {
                    Authorization: this.getAuthToken()
                },
                onload: (res) => {
                    const blob = new Blob([res.response], { type: res.response.type });
                    const url = URL.createObjectURL(blob);

                    const a = document.createElement('a');
                    a.href = url;
                    a.download = filename;
                    a.click();

                    URL.revokeObjectURL(url);
                    GM_notification({
                        title: '下载完成',
                        text: `文件已保存为：${filename}`,
                        timeout: 3000
                    });
                },
                onerror: (err) => {
                    this.showError('下载失败', err);
                }
            });
        }

        showError(title, error) {
            console.error(`${title}:`, error);
            this.downloadBtn.style.background = STATE_COLORS.error;
            this.downloadBtn.textContent = '点击重试';
            this.downloadBtn.onclick = () => location.reload();

            GM_notification({
                title: title,
                text: error.message || error,
                timeout: 5000
            });
        }
    }

    // 延迟初始化确保DOM加载完成
    setTimeout(() => new SingleFileDownloader(), 1500);
})();
