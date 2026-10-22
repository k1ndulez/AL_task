# STM32F103 江科大教程复现

跟着江协科技（江科大）STM32 入门教程逐章复现的练习工程合集。

- 芯片：**STM32F103C8T6**（蓝板，LQFP48，64KB Flash / 20KB RAM）
- 开发方式：**STM32CubeMX + CMake + arm-none-eabi-gcc + VS Code**（不是 Keil）
- 每章一个独立工程，工程内自带 `.ioc`，可用 CubeMX 重新生成
- 时钟：HSE 8 MHz × 9 = **72 MHz**；SWD 调试

## 目录

| # | 章节 | 工程目录 | 外设 / 内容 |
| --- | --- | --- | --- |
| 01 | 1流水灯 | `1流水灯/water` | GPIO 输出，LED 轮流点亮 |
| 02 | 2蜂鸣器 | `2蜂鸣器/fengmingqi` | GPIO 输出驱动蜂鸣器 |
| 03 | 3按键控制小灯亮灭 | `3按键控制小灯亮灭/controltheled` | GPIO 输入 + 按键消抖 |
| 04 | 4光敏电阻器控制蜂鸣器 | `4光敏电阻器控制蜂鸣器/guangming` | 光敏模块数字输出 → 蜂鸣器 |
| 05 | 5定时器定时中断 | `5定时器定时中断/timbreak` | TIM2 定时中断 |
| 06 | 6对射式红外传感器计次 | `6对射式红外传感器计次/duishe` | PB13 外部中断 EXTI13 计数 + OLED |
| 07 | 7pwm驱动led呼吸灯 | `7pwm驱动led呼吸灯` | 笔记与截图（无独立工程） |
| 08 | 8pwm驱动舵机 | `8pwm驱动舵机/servo` | TIM3 PWM 50 Hz 驱动舵机 |
| 09 | 9输入捕获测频率+占空比 | `9输入捕获测频率+占空比/capturethepwm` | TIM2 / TIM3 输入捕获 |
| 10 | 10考核项目复现 | `10考核项目复现/redotheal` | TIM2 / TIM3 综合考核 |
| 11 | 11编码器接口测速 | `11编码器接口测速/vofenco` | TIM3 编码器模式 + OLED 显示 |
| 12 | 12USART通信 | `12USART通信/usart` | USART1（PA9/PA10）115200-8-N-1 |
| 13 | 13ADC模数转换 | — | 待做 |
| 14 | 14ADC多通道 | — | 待做 |
| 15 | 15 I2C 读写 MPU6050 | — | 待做 |

## 怎么编译

每个工程目录下（以 `12USART通信/usart` 为例）：

```bash
cd 12USART通信/usart
cmake --preset Debug
cmake --build --preset Debug
```

需要：
- CMake ≥ 3.22
- Ninja
- `arm-none-eabi-gcc`（工具链文件在 `cmake/gcc-arm-none-eabi.cmake`）
- 烧录：ST-Link + STM32CubeProgrammer，或 VS Code 的 STM32 扩展

> 生成的 `build/` 与 Keil 的 `MDK-ARM/` 目录已在 `.gitignore` 中排除；
> `Drivers/` 是 CubeMX 生成的 HAL 库，随工程一起提交，保证 clone 后可直接编译。

## 备注

- 各章 `Core/Src/main.c` 里带 `USER CODE` 注释的区块是手写代码，其余是 CubeMX 生成。
- 第 1 章的 `.ioc` 名为 `1111.ioc`，第 6 章的 `.ioc` 名为 `jishu.ioc` —— 是从早期工程复制过来的，不影响编译。
- 源码注释保持 ASCII（本机 Keil/CubeIDE 对中文注释兼容性一般）。
