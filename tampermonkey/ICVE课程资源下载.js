// ==UserScript==
// @name         ICVE课程资源下载
// @namespace    http://tampermonkey.net/
// @version      2.1
// @description  支持下载队列状态显示、文件路径提示、去重等功能
// @author       ashin
// @match        https://zyk.icve.com.cn/icve-study/coursePreview/courseIndex
// @grant        GM_xmlhttpRequest
// @grant        GM_setClipboard
// @grant        GM_download
// @connect      zyk.icve.com.cn
// @connect      file.icve.com.cn
// @connect      *
// @require      https://cdnjs.cloudflare.com/ajax/libs/limonte-sweetalert2/11.4.8/sweetalert2.min.js
// ==/UserScript==

(function () {
    'use strict';

    const API_BASE = 'https://zyk.icve.com.cn/prod-api/teacher/courseContent';

    const AUTH = {
        getToken: () => document.cookie.match(/Token=([^;]+)/)?.[1],
        headers: () => ({ Authorization: `Bearer ${AUTH.getToken()}` })
    };

    class ResourceManager {
        constructor() {
            this.downloadQueue = [];
            this.isDownloading = false;
            this.fileStats = { all: 0, video: 0, doc: 0, ppt: 0 };
            this.initUI();
        }

        initUI() {
            this.injectStyles();
            this.createMainButton();
            this.createModal();
        }

        createMainButton() {
            const btn = Object.assign(document.createElement('button'), {
                className: 'icve-dl-btn',
                textContent: '📁 资源管理器',
                onclick: () => this.loadResources()
            });
            Object.assign(btn.style, {
                position: 'fixed',
                bottom: '20px',
                right: '20px',
                zIndex: 9999,
                padding: '12px 24px',
                background: '#2196F3',
                color: 'white',
                border: 'none',
                borderRadius: '5px',
                cursor: 'pointer',
                boxShadow: '0 2px 10px rgba(0,0,0,0.2)'
            });
            document.body.appendChild(btn);
        }

        getFileType(ext) {
            const videoExtensions = [
                'mp4', 'avi', 'mov', 'wmv', 'flv',
                'mkv', 'webm', 'mpg', 'mpeg', '3gp'
            ];
            const pptExtensions = ['ppt', 'pptx']; // 新增PPT类型判断
            if (videoExtensions.includes(ext)) return 'video';
            if (pptExtensions.includes(ext)) return 'ppt'; // 返回ppt类型
            return 'doc';
        }

        createModal() {
            this.modal = Object.assign(document.createElement('div'), {
                className: 'icve-modal',
                innerHTML: `
                    <div class="header">
                        <h3>课程资源列表</h3>
                        <span class="close">&times;</span>
                    </div>
                <div class="toolbar">
                    <button class="filter active" data-type="all">全部</button>
                    <button class="filter" data-type="video">视频</button>
                    <button class="filter" data-type="doc">文档</button>
                    <button class="filter" data-type="ppt">PPT</button>
                    <button class="select-all">全选</button>
                    <button class="download-selected">下载选中项</button>
                </div>
                    <div class="table-wrap">
                        <table>
                            <thead>
                                <tr>
                                    <th><input type="checkbox" class="master-check"></th>
                                    <th>文件名</th>
                                    <th>状态</th>
                                    <th>操作</th>
                                </tr>
                            </thead>
                            <tbody class="file-list"></tbody>
                        </table>
                    </div>
                `
            });

            this.modal.addEventListener('click', e => {
                const target = e.target;
                if (target.classList.contains('close')) this.hideModal();
                if (target.classList.contains('master-check')) this.toggleAll(target.checked);
                if (target.classList.contains('filter')) this.handleFilter(target);
                if (target.classList.contains('select-all')) this.toggleAll(true);
                if (target.classList.contains('download-selected')) this.processDownload();
                if (target.classList.contains('copy-btn')) this.handleCopy(target);
                if (target.classList.contains('download-btn')) this.handleSingleDownload(target);
                if (target.matches('input[type="checkbox"]')) this.updateSelectedCount();
            });

            document.body.appendChild(this.modal);
        }

        async loadResources() {
            try {
                const courseId = await this.waitForCourseId();
                const data = await this.fetchCourseData(courseId);
                const files = this.parseResources(data.data);
                this.renderFileList(files);
                this.updateButtonCounts();
                this.showModal();
            } catch (error) {
                this.showAlert('错误', error.message, 'error');
            }
        }

        async fetchCourseData(courseId) {
            const response = await this.apiRequest(`${API_BASE}/studyDesignList?courseInfoId=${courseId}`);
            if (!response.data?.length) throw new Error('未找到课程资源');
            return response;
        }

        parseResources(nodes) {
            const result = [];
            const seenUrls = new Set();

            const traverse = (items, path = []) => {
                items.forEach(item => {
                    const newPath = [...path, item.name];
                    if (item.fileUrl) {
                        // 去重逻辑：只保留第一个出现的fileUrl
                        if (item.fileUrl && seenUrls.has(item.fileUrl)) return;
                        if (item.fileUrl) seenUrls.add(item.fileUrl);

                        const fileExt = this.getFileExt(item.fileUrl);
                        result.push({
                            id: item.fileId || item.id,
                            name: item.name,
                            type: this.getFileType(fileExt),
                            ext: fileExt,
                            path: path.join(' - ')
                        });
                    }
                    if (item.children) traverse(item.children, newPath);
                });
            };

            traverse(nodes);

            // 统计文件类型数量
            this.fileStats = result.reduce((stats, file) => {
                stats.all++;
                stats[file.type]++;
                return stats;
            }, { all: 0, video: 0, doc: 0, ppt: 0 });

            return result;
        }

        getFileExt(url) {
            return (url.split('.').pop() || '').split(/[?#]/)[0].toLowerCase();
        }

        handleFilter(target) {
            const type = target.dataset.type;
            this.modal.querySelectorAll('.filter').forEach(btn => btn.classList.remove('active'));
            target.classList.add('active');

            this.modal.querySelectorAll('tr[data-type]').forEach(row => {
                row.style.display = type === 'all' || row.dataset.type === type ? '' : 'none';
            });

            this.updateSelectedCount();
            this.modal.querySelector('.master-check').checked = false;
        }

        updateButtonCounts() {
            // 更新筛选按钮计数
            this.modal.querySelectorAll('.filter').forEach(btn => {
                const type = btn.dataset.type;
                btn.textContent = `${{
                    all: '全部',
                    video: '视频',
                    doc: '文档',
                    ppt: 'PPT'
                }[type]}（${this.fileStats[type]}）`;
            });
        }

        async processDownload() {
            const selected = this.getSelectedFiles();
            if (!selected.length) return this.showAlert('提示', '请先选择要下载的文件', 'warning');

            selected.forEach(file => this.updateFileStatus(file.id, '等待下载'));
            this.downloadQueue.push(...selected);
            this.showAlert('下载队列', `已添加${selected.length}个文件到下载队列`, 'info');
            this.processQueue();
        }

        async processQueue() {
            if (this.isDownloading || !this.downloadQueue.length) return;
            this.isDownloading = true;

            while (this.downloadQueue.length > 0) {
                const file = this.downloadQueue.shift();
                try {
                    this.updateFileStatus(file.id, '开始下载');
                    await this.downloadFile(file);
                } catch (error) {
                    this.updateFileStatus(file.id, `失败: ${error.message}`);
                }
            }

            this.isDownloading = false;
        }

        async fetchAndDownloadFile(url, filename, fileId) {
            return new Promise((resolve, reject) => {
                GM_xmlhttpRequest({
                    method: 'GET',
                    url: url,
                    responseType: 'blob',
                    headers: { 'Origin': window.location.origin },
                    onprogress: (progress) => {
                        if (progress.lengthComputable) {
                            const percent = Math.round((progress.loaded / progress.total) * 100);
                            this.updateFileStatus(fileId, `下载中 ${percent}%`);
                        }
                    },
                    onload: (response) => {
                        if (response.status === 200) {
                            const blob = new Blob([response.response], { type: response.responseHeaders['Content-Type'] });
                            const a = document.createElement('a');
                            a.href = URL.createObjectURL(blob);
                            a.download = filename;
                            document.body.appendChild(a);
                            a.click();
                            document.body.removeChild(a);
                            this.updateFileStatus(fileId, '下载完成');
                            resolve();
                        } else {
                            this.updateFileStatus(fileId, `失败: HTTP ${response.status}`);
                            reject(new Error(`HTTP ${response.status}`));
                        }
                    },
                    onerror: (error) => {
                        this.updateFileStatus(fileId, '下载失败');
                        reject(error);
                    }
                });
            });
        }

        async downloadFile(file) {
            try {
                this.updateFileStatus(file.id, '获取地址中...');
                const { data } = await this.apiRequest(`${API_BASE}/${file.id}`);
                if (!data?.fileUrl) throw new Error('无效的下载地址');

                await this.fetchAndDownloadFile(data.fileUrl, `${file.name}`, file.id);
            } catch (error) {
                this.updateFileStatus(file.id, `失败: ${error.message}`);
                throw error;
            }
        }

        handleSingleDownload(button) {
            const row = button.closest('tr');
            const fileId = row.dataset.id;
            const fileName = row.cells[1].textContent;
            const fileExt = row.dataset.type;

            this.updateFileStatus(fileId, '开始下载');
            this.downloadFile({
                id: fileId,
                name: fileName,
                ext: fileExt
            }).catch(() => { });
        }

        handleCopy(button) {
            const row = button.closest('tr');
            const fileId = row.dataset.id;

            this.apiRequest(`${API_BASE}/${fileId}`)
                .then(({ data }) => {
                    GM_setClipboard(data.fileUrl, 'text');
                    this.showAlert('成功', '下载地址已复制到剪贴板', 'success');
                })
                .catch(() => {
                    this.showAlert('错误', '获取下载地址失败', 'error');
                });
        }

        renderFileList(files) {
            const tbody = this.modal.querySelector('.file-list');
            tbody.innerHTML = files.map(file => `
                <tr data-id="${file.id}" data-type="${file.type}">
                    <td><input type="checkbox"></td>
                    <td title="${file.path}">${file.name}.${file.ext}</td>
                    <td class="status">未下载</td>
                    <td>
                        <button class="copy-btn">获取地址</button>
                        <button class="download-btn">下载</button>
                    </td>
                </tr>
            `).join('');
        }

        updateFileStatus(id, text) {
            const row = this.modal.querySelector(`tr[data-id="${id}"]`);
            if (row) row.querySelector('.status').textContent = text;
        }

        updateSelectedCount() {
            const count = this.getSelectedFiles().length;
            this.modal.querySelector('.download-selected').textContent = `下载选中项（${count}）`;
        }

        async waitForCourseId() {
            return new Promise(resolve => {
                const check = () => {
                    const vue = document.querySelector('#app')?.__vue__;
                    const courseId = vue?.$store?.getters?.courseInfo?.courseInfoId;
                    if (courseId) resolve(courseId);
                    else setTimeout(check, 500);
                };
                check();
            });
        }

        apiRequest(url) {
            return new Promise((resolve, reject) => {
                GM_xmlhttpRequest({
                    method: 'GET',
                    url,
                    headers: AUTH.headers(),
                    onload: res => (res.status === 200)
                        ? resolve(JSON.parse(res.responseText))
                        : reject(new Error(`HTTP ${res.status}`)),
                    onerror: reject
                });
            });
        }

        getSelectedFiles() {
            return Array.from(this.modal.querySelectorAll('tbody tr:not([style*="none"]) input:checked'))
                .map(input => {
                    const row = input.closest('tr');
                    return {
                        id: row.dataset.id,
                        name: row.cells[1].textContent,
                        ext: row.dataset.type
                    };
                });
        }
        toggleAll(checked) {
            this.modal.querySelectorAll('tbody tr:not([style*="none"]) input[type="checkbox"]')
                .forEach(input => input.checked = checked);
            this.updateSelectedCount();
        }


        showModal() {
            this.modal.style.display = 'block';
            Object.assign(this.modal.style, {
                position: 'fixed',
                top: '50%',
                left: '50%',
                transform: 'translate(-50%, -50%)',
                background: 'white',
                padding: '20px',
                borderRadius: '8px',
                boxShadow: '0 0 20px rgba(0,0,0,0.2)',
                zIndex: 10000,
                maxWidth: '90vw',
                maxHeight: '80vh',
                overflow: 'auto'
            });
        }

        hideModal() {
            this.modal.style.display = 'none';
        }

        showAlert(title, text, icon) {
            Swal.fire({
                title,
                text,
                icon,
                position: 'top-end',
                toast: true,
                timer: 3000,
                showConfirmButton: false,
                customClass: {
                    popup: 'icve-alert'
                }
            });
        }

        injectStyles() {
            const css = `
                .icve-modal {
                    display: none;
                    background: white;
                    min-width: 800px;
                    font-family: system-ui, -apple-system, sans-serif;
                }
                .icve-modal .header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    padding: 15px;
                    border-bottom: 1px solid #eee;
                }
                .icve-modal .close {
                    cursor: pointer;
                    font-size: 24px;
                    color: #666;
                    padding: 0 8px;
                }
                .icve-modal .close:hover {
                    color: #333;
                }
                .icve-modal .toolbar {
                    padding: 10px;
                    background: #f8f9fa;
                    display: flex;
                    gap: 8px;
                    border-bottom: 1px solid #eee;
                }
                .icve-modal .toolbar button {
                    padding: 6px 12px;
                    border: 1px solid #ddd;
                    border-radius: 4px;
                    cursor: pointer;
                    background: white;
                    transition: all 0.2s;
                }
                .icve-modal .toolbar button:hover {
                    background: #f0f0f0;
                }
                .icve-modal .toolbar button.active {
                    background: #9C27B0 !important;
                    color: white !important;
                    border-color: #7B1FA2;
                }
                .icve-modal .table-wrap {
                    padding: 15px;
                }
                .icve-modal table {
                    width: 100%;
                    border-collapse: collapse;
                }
                .icve-modal th, .icve-modal td {
                    padding: 12px;
                    border: 1px solid #eee;
                    text-align: left;
                }
                .icve-modal th {
                    background: #f8f9fa;
                    font-weight: 500;
                }
                .status {
                    color: #666;
                    min-width: 100px;
                    font-size: 0.9em;
                }
                .download-btn {
                    margin-left: 8px;
                    background: #4CAF50 !important;
                    color: white !important;
                    border-color: #45a049 !important;
                }
                .copy-btn {
                    background: #2196F3 !important;
                    color: white !important;
                    border-color: #1976D2 !important;
                }
                .icve-alert {
                    z-index: 10001 !important;
                    margin-top: 50px !important;
                }
            `;
            const style = document.createElement('style');
            style.textContent = css;
            document.head.appendChild(style);
        }
    }

    window.addEventListener('load', () => new ResourceManager());
})();
