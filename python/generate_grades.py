import pandas as pd
import numpy as np
import openpyxl

# 设置参数
mu = 75
sigma = 6.9282
size = 44
max_attempts = 1000

# 初始化成绩数组
A = np.zeros(size)
B = np.zeros(size)
T = np.zeros(size)

attempt = 0
while attempt < max_attempts:
    # 随机生成平时和期末成绩
    new_A = np.random.normal(mu, sigma, size).clip(0, 100).round(1)
    new_B = np.random.normal(mu, sigma, size).clip(0, 100).round(1)
    new_T = 0.4 * new_A + 0.6 * new_B

    # 等待所有成绩及格
    passed = new_T >= 60
    if np.all(passed):
        break
    attempt += 1

# 将成绩保存到Excel文件
# 文件路径
file_name = '学生成绩.xlsx'

# 创建DataFrame
df = pd.DataFrame({
    '平时成绩': new_A,
    '期末成绩': new_B,
    '总成绩': new_T
})

# 保存到Excel
with pd.ExcelWriter(file_name, engine='openpyxl') as writer:
    df.to_excel(writer, sheet_name='成绩', index=False)

# 打开Excel文件查看
import os
os.startfile(file_name)
