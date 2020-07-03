# dell_ipmi_fan_control_pve

Dell服务器风扇控制脚本, 基于impi协议控制
* 测试硬件：DELL R720xd
* 测试环境：
  - PVE6.2-6

1.相比于原版添加了PVE6.x（Debian 10）的支持,只在PVE下测试过
2.增加了4档调节选项,可以调节启动温度和对应的风扇转速,关闭第三方pcie检测
