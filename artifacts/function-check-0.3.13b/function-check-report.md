# 0.3.13 自动动线巡检报告

## 结论

通过。当前环境没有可用的真实 Simulator tap 工具，因此本轮使用 app 内置自动动线模拟用户逐步进入各界面，并通过阶段徽标和截图拼图确认覆盖。

## 覆盖动线

1. 家人关系网络
2. 分身代聊
3. 东京地点
4. 大阪 Moments
5. 香港家人互动
6. 记录 Moment
7. 分身控制台
8. 回到家人

## 截图证据

- 拼图：`artifacts/function-check-0.3.13b/contact-sheet.png`
- 时间序列截图：`artifacts/function-check-0.3.13b/t01.png` 到 `artifacts/function-check-0.3.13b/t14.png`

## 图像差异检查

- 自动巡检跨页面差异明显：
  - `t06 -> t07`：34.86%
  - `t08 -> t09`：22.07%
  - `t09 -> t10`：36.17%
  - `t12 -> t13`：8.07%
- 相邻帧 0% 的情况为同一阶段停留截图，不代表卡死。

## 静态截图 QA

- `PASS_COUNT=17`
- `FAIL_COUNT=0`
- `RESULT=OK`
