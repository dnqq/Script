// ==UserScript==
// @name         智慧职教 MOOC 自动答题
// @namespace    http://tampermonkey.net/
// @version      1.1
// @description  自动完成智慧职教（MOOC）平台上的题目，需要自行配置AI接口。
// @author       Kilo Code
// @match        https://ai.icve.com.cn/preview-exam/*
// @grant        GM_xmlhttpRequest
// @connect      *
// @license      MIT
// ==/UserScript==

(function() {
    'use strict';

    // --- 配置区域 ---
    const AI_API_ENDPOINT = 'https://ai.xyz/v1/chat/completions'; // 在这里替换成你的AI接口地址
    const API_KEY = 'sk-FskPt1qJejgGbSqvsSlXSjBV1WQ'; // 在这里替换成你的API Key
    const AI_MODEL = 'gemini-2.5-pro'; // 在这里替换成你的AI模型
    // --- 配置区域结束 ---

    // 创建并添加“一键答题”按钮
    const solveButton = document.createElement('button');
    solveButton.innerHTML = '🚀 AI一键答题';
    solveButton.style.position = 'fixed';
    solveButton.style.bottom = '150px';
    solveButton.style.right = '20px';
    solveButton.style.zIndex = '9999';
    solveButton.style.padding = '10px 20px';
    solveButton.style.backgroundColor = '#4CAF50';
    solveButton.style.color = 'white';
    solveButton.style.border = 'none';
    solveButton.style.borderRadius = '5px';
    solveButton.style.cursor = 'pointer';
    solveButton.style.boxShadow = '0 2px 5px rgba(0,0,0,0.2)';
    document.body.appendChild(solveButton);

    solveButton.addEventListener('click', solveAndGoNext);

    // 添加调试日志函数
    function debugLog(message, data = null) {
        console.log('[智慧职教自动答题] ' + message, data);
    }

    function showToast(message, duration = 3000) {
        const toast = document.createElement('div');
        toast.textContent = message;
        toast.style.position = 'fixed';
        toast.style.bottom = '20px';
        toast.style.left = '50%';
        toast.style.transform = 'translateX(-50%)';
        toast.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
        toast.style.color = 'white';
        toast.style.padding = '10px 20px';
        toast.style.borderRadius = '5px';
        toast.style.zIndex = '10000';
        document.body.appendChild(toast);
        setTimeout(() => {
            document.body.removeChild(toast);
        }, duration);
    }

    async function solveAndGoNext() {
        debugLog('开始执行自动答题功能');
        showToast('开始提取当前题目...');
        const question = extractCurrentQuestion();
        if (!question) {
            debugLog('未找到题目，或已是最后一题，停止执行');
            showToast('未找到题目或已完成所有题目。');
            return;
        }
        debugLog('提取到的题目:', question);

        showToast(`正在请求AI解答...`);
        try {
            const answers = await getAnswersFromAI([question]);
            if (answers.length > 0) {
                const answerToFill = answers[0];
                answerToFill.id = question.id; // Add the ID from the extracted question object
                debugLog('AI返回的答案:', answerToFill);
                showToast('获取答案成功，正在自动填写...');
                fillAnswer(answerToFill);
                showToast('本题已完成！2秒后将自动跳转到下一题。');

                // 等待2秒后点击下一题
                setTimeout(() => {
                    const nextButton = document.querySelector('.center_btn button:last-child');
                    if (nextButton && !nextButton.disabled && nextButton.innerText.includes('下一题')) {
                        debugLog('点击下一题');
                        nextButton.click();
                        // 等待页面加载新题目后再次执行
                        setTimeout(solveAndGoNext, 2000);
                    } else {
                        showToast('已经是最后一题或无法点击下一题。');
                        debugLog('已经是最后一题或无法点击下一题。');
                    }
                }, 2000);
            } else {
                 showToast('AI未能返回有效答案。');
                 debugLog('AI未能返回有效答案。');
            }
        } catch (error) {
            console.error('答题失败:', error);
            debugLog('答题失败:', error.message);
            showToast(`答题失败: ${error.message}`);
        }
    }

    function extractCurrentQuestion() {
        debugLog('开始提取当前题目元素');
        const questionElement = document.querySelector('.content-item > div');
        if (!questionElement) {
            debugLog('未找到题目元素');
            return null;
        }

        const titleNumElement = questionElement.querySelector('.judge-title-num, .single-title-num, .multiple-title-num');
        const questionTextElement = questionElement.querySelector('.judge-title-content p, .single-title-content p, .multiple-title-content p');

        if (!titleNumElement || !questionTextElement) {
            console.warn('未找到题目标题或内容元素');
            return null;
        }

        const titleText = titleNumElement.innerText;
        const questionText = questionTextElement.innerText.trim();
        const questionId = questionElement.id;
        const questionIndex = parseInt(titleText.match(/^(\d+)/)[1], 10);

        let type = '';
        if (titleText.includes('判断题')) {
            type = 'true_false';
        } else if (titleText.includes('单选题')) {
            type = 'single_choice';
        } else if (titleText.includes('多选题')) {
            type = 'multiple_choice';
        } else {
            console.warn(`未识别的题目类型: ${titleText}`);
            return null;
        }

        const options = [];
        const optionElements = questionElement.querySelectorAll('.ivu-radio-wrapper, .ivu-checkbox-wrapper');
        optionElements.forEach(optElement => {
            const labelElement = optElement.querySelector('.judge-item-xx, .single-item-xx, .multiple-item-xx');
            const textElement = optElement.querySelector('.judge-item-xxnr > span:last-child, .single-item-xxnr > span:last-child, .multiple-item-xxnr > span:last-child');
            if (labelElement && textElement) {
                const label = labelElement.innerText.trim();
                const text = textElement.innerText.trim();
                options.push(`${label}. ${text}`);
            } else { // 兼容判断题
                 const textContent = optElement.innerText.trim();
                 if(textContent){
                     options.push(textContent);
                 }
            }
        });

        return {
            id: questionId,
            index: questionIndex,
            type: type,
            stem: questionText,
            options: options
        };
    }

    function getAnswersFromAI(questions) {
        return new Promise((resolve, reject) => {
            debugLog('准备发送请求到AI接口');
            const formattedQuestions = questions.map(q => {
                return `${q.index}. [${q.type === 'single_choice' ? '单选' : q.type === 'multiple_choice' ? '多选' : '判断'}] ${q.stem}\n${q.options.join('\n')}`;
            }).join('\n\n');

            const prompt = `你是一个答题助手，请根据以下题目，给出最准确的答案。请严格按照“题号. 答案”的格式输出，例如：“1. C”或“6. A,B,D”。不要包含任何解释或其他无关内容。\n\n${formattedQuestions}`;

            // 新增函数：从AI接口返回的数据中提取答案内容
            function extractAIResponseContent(data) {
                if (data && Array.isArray(data.choices) && data.choices.length > 0 && data.choices[0].message && data.choices[0].message.content) {
                    debugLog('响应格式确认为OpenAI');
                    return data.choices[0].message.content;
                }
                debugLog('未知的AI接口返回格式');
                console.log('未知的AI接口返回格式，原始数据:', JSON.stringify(data, null, 2));
                return null;
            }

            GM_xmlhttpRequest({
                method: 'POST',
                url: AI_API_ENDPOINT,
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${API_KEY}`
                },
                data: JSON.stringify({
                    model: AI_MODEL,
                    messages: [{ role: "user", content: prompt }],
                    temperature: 0
                }),
                onload: function(response) {
                    debugLog('收到AI接口响应');
                    try {
                        const data = JSON.parse(response.responseText);
                        debugLog('AI接口返回的数据:', data);
                        // 根据你的AI接口返回的数据结构来解析答案
                        // 添加更健壮的错误处理来检查返回数据的结构
                        console.log('AI接口返回的原始数据:', data);
                        const aiResponse = extractAIResponseContent(data);
                        if (!aiResponse) {
                            console.error('无法从AI接口返回数据中提取答案内容:', data);
                            debugLog('无法从AI接口返回数据中提取答案内容:', data);
                            reject(new Error('无法从AI接口返回数据中提取答案内容'));
                            return;
                        }
                        const answers = aiResponse.split('\n').map(line => {
                            const match = line.match(/^(\d+)\.\s*([A-Z,]+)/);
                            if (match) {
                                return {
                                    index: parseInt(match[1], 10),
                                    answer: match[2].split(',').map(a => a.trim())
                                };
                            }
                            // 如果标准格式不匹配，尝试其他可能的格式
                            const match2 = line.match(/^(\d+)\s*:\s*([A-Z,]+)/);
                            if (match2) {
                                return {
                                    index: parseInt(match2[1], 10),
                                    answer: match2[2].split(',').map(a => a.trim())
                                };
                            }
                            // 如果还是不匹配，记录警告信息
                            if (line.trim() !== '') {
                                console.warn('无法解析答案行:', line);
                                debugLog('无法解析答案行:', line);
                            }
                            return null;
                        }).filter(Boolean);
                        debugLog('解析答案完成，答案数量:', answers.length);
                        resolve(answers);
                    } catch (e) {
                        console.error('解析AI返回结果失败:', e, response.responseText);
                        debugLog('解析AI返回结果失败:', e.message);
                        reject(new Error('解析AI返回结果失败: ' + e.message));
                    }
                },
                onerror: function(error) {
                    console.error('请求AI接口失败:', error);
                    debugLog('请求AI接口失败:', error);
                    reject(new Error('请求AI接口失败: ' + JSON.stringify(error)));
                }
            });
        });
    }

    function fillAnswer(answer) {
        debugLog('开始填写答案:', answer);
        const questionElement = document.getElementById(answer.id);
        if (!questionElement) {
            console.warn(`未找到ID为 ${answer.id} 的题目元素`);
            debugLog(`未找到ID为 ${answer.id} 的题目元素`);
            return;
        }

        if (answer.type === 'true_false') {
            const correctOptionText = answer.answer[0] === 'A' || answer.answer[0] === '正确' ? '正确' : '错误';
            const optionLabels = questionElement.querySelectorAll('.ivu-radio-wrapper');
            optionLabels.forEach(label => {
                if (label.innerText.includes(correctOptionText)) {
                    label.click();
                }
            });
        } else {
            answer.answer.forEach(ans => {
                const optionLabels = questionElement.querySelectorAll('.ivu-radio-wrapper, .ivu-checkbox-wrapper');
                optionLabels.forEach(label => {
                    const optionSpan = label.querySelector('.judge-item-xx, .single-item-xx, .multiple-item-xx');
                    if (optionSpan && optionSpan.innerText.trim() === ans) {
                        label.click();
                    }
                });
            });
        }
        debugLog('答案填写完成');
    }
})();