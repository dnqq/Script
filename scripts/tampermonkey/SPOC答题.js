// ==UserScript==
// @name         智慧职教 SPOC 自动答题
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  自动完成智慧职教（SPOC）平台上的题目，需要自行配置AI接口。
// @author       Kilo Code
// @match        https://zjy2.icve.com.cn/study/spocjobTest*
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

    solveButton.addEventListener('click', solveAllQuestions);

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

    async function solveAllQuestions() {
        debugLog('开始执行自动答题功能');
        showToast('开始提取题目...');
        const questions = extractQuestions();
        debugLog('提取到的题目数量:', questions.length);
        console.log('提取到的题目:', questions);
        if (questions.length === 0) {
            debugLog('未找到题目，停止执行');
            showToast('未找到题目。');
            return;
        }

        showToast(`共找到 ${questions.length} 道题，正在请求AI解答...`);
        debugLog('开始请求AI接口解答题目');

        try {
            const answers = await getAnswersFromAI(questions);
            debugLog('AI返回的答案数量:', answers.length);
            console.log('AI返回的答案:', answers);
            showToast('获取答案成功，正在自动填写...');
            fillAnswers(answers);
            showToast('所有题目已完成！');
        } catch (error) {
            console.error('答题失败:', error);
            debugLog('答题失败:', error.message);
            showToast(`答题失败: ${error.message}`);
        }
    }

    function extractQuestions() {
        debugLog('开始提取题目元素');
        const questionElements = document.querySelectorAll('.subjectDet');
        debugLog('找到题目元素数量:', questionElements.length);
        const questions = [];

        questionElements.forEach((qElement, index) => {
            const titleElement = qElement.querySelector('.title');
            const questionTextElement = qElement.querySelector('h5 .htmlP p');
            if (!titleElement) {
                console.warn(`第${index + 1}题未找到标题元素`);
                return;
            }
            if (!questionTextElement) {
                console.warn(`第${index + 1}题未找到题目文本元素`);
                return;
            }

            const titleText = titleElement.innerText;
            const questionText = questionTextElement.innerText.trim();
            let type = '';
            if (titleText.includes('单选题')) {
                type = 'single_choice';
            } else if (titleText.includes('多选题')) {
                type = 'multiple_choice';
            } else if (titleText.includes('判断题')) {
                type = 'true_false';
            } else {
                console.warn(`第${index + 1}题未识别的题目类型: ${titleText}`);
                return;
            }

            const options = [];
            const optionElements = qElement.querySelectorAll('.optionList .el-radio, .optionList .el-checkbox');
            if (optionElements.length === 0) {
                console.warn(`第${index + 1}题未找到选项元素`);
                return;
            }
            optionElements.forEach(optElement => {
                const labelSpan = optElement.querySelector('.el-radio__label span:first-child, .el-checkbox__label span:first-child');
                const textSpan = optElement.querySelector('.el-radio__label .htmlP p, .el-checkbox__label .htmlP p');
                if (labelSpan && textSpan) {
                    const label = labelSpan.innerText.replace('.', '').trim();
                    const text = textSpan.innerText.trim();
                    options.push(`${label}. ${text}`);
                } else { // 兼容判断题的简单文本
                    const labelTextElement = optElement.querySelector('.el-radio__label, .el-checkbox__label');
                    if (labelTextElement) {
                         const fullText = labelTextElement.innerText.trim();
                         options.push(fullText);
                    } else {
                        console.warn(`第${index + 1}题的选项元素未找到标签或文本:`, optElement);
                    }
                }
            });

            questions.push({
                id: qElement.id,
                index: index + 1,
                type: type,
                stem: questionText,
                options: options
            });
        });

        debugLog('题目提取完成，共提取到题目数量:', questions.length);
        return questions;
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
                // 检查OpenAI格式
                if (data && Array.isArray(data.choices) && data.choices.length > 0 && data.choices[0].message && data.choices[0].message.content) {
                    debugLog('检测到OpenAI格式响应');
                    return data.choices[0].message.content;
                }
                // 检查Google Gemini格式 (如果适用)
                // 这里可以根据实际的Google Gemini返回格式进行调整
                // 例如，如果返回格式是 { "content": "..." }，则可以这样处理：
                if (data && data.content) {
                    debugLog('检测到Google Gemini格式响应');
                    return data.content;
                }
                // 检查可能的其他格式
                if (data && data.data && data.data.content) {
                    debugLog('检测到data.content格式响应');
                    return data.data.content;
                }
                if (data && data.result && data.result.content) {
                    debugLog('检测到result.content格式响应');
                    return data.result.content;
                }
                if (data && data.response && data.response.content) {
                    debugLog('检测到response.content格式响应');
                    return data.response.content;
                }
                if (data && data.message && data.message.content) {
                    debugLog('检测到message.content格式响应');
                    return data.message.content;
                }
                if (data && data.text) {
                    debugLog('检测到text格式响应');
                    return data.text;
                }
                if (data && data.answer) {
                    debugLog('检测到answer格式响应');
                    return data.answer;
                }
                // 如果以上格式都不匹配，尝试返回整个对象的字符串表示（用于调试）
                if (data) {
                    console.log('未知的AI接口返回格式，返回原始数据字符串表示:', JSON.stringify(data, null, 2));
                    debugLog('未知的AI接口返回格式，返回原始数据字符串表示');
                    return JSON.stringify(data);
                }
                // 如果数据为空，返回null
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
                    // 这里是根据你自己的AI接口格式来构造请求体
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

    function fillAnswers(answers) {
        debugLog('开始填写答案，答案数量:', answers.length);
        answers.forEach(answer => {
            const questionElement = document.querySelector(`.subjectDet:nth-of-type(${answer.index})`);
            if (!questionElement) {
                console.warn(`未找到第${answer.index}题的元素`);
                debugLog(`未找到第${answer.index}题的元素`);
                return;
            }

            const questionType = questionElement.querySelector('.title').innerText;

            if (questionType.includes('判断题')) {
                const correctOption = answer.answer[0] === 'A' || answer.answer[0] === '正确' ? 'A' : 'B';
                const optionLabels = questionElement.querySelectorAll('.el-radio__label');
                if (optionLabels.length === 0) {
                    console.warn(`第${answer.index}题未找到选项标签`);
                    debugLog(`第${answer.index}题未找到选项标签`);
                    return;
                }
                optionLabels.forEach(label => {
                    if ((correctOption === 'A' && label.innerText.includes('正确')) || (correctOption === 'B' && label.innerText.includes('错误'))) {
                        label.click();
                    }
                });
            } else {
                answer.answer.forEach(ans => {
                    const optionLabels = questionElement.querySelectorAll('.el-radio__label, .el-checkbox__label');
                    if (optionLabels.length === 0) {
                        console.warn(`第${answer.index}题未找到选项标签`);
                        debugLog(`第${answer.index}题未找到选项标签`);
                        return;
                    }
                    optionLabels.forEach(label => {
                        const optionSpan = label.querySelector('span:first-child');
                        if (optionSpan && optionSpan.innerText.trim().startsWith(ans)) {
                            label.click();
                        }
                    });
                });
            }
        });
        debugLog('答案填写完成');
    }
})();