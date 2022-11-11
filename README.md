# LibIMobileDevice-Debug
debug libimobiledevice components with xcode

#### 踩坑日记

前提：因为俺有两台的电脑，处理器分别为 `Apple` 和 `Inter`。

##### 编译依赖库的报错：

- 这个实在太多了整理整理在补充。

##### 编译报错`Undefined symbols for architecture x86_64`：

- 注意制作的`.a`文件支持的架构与当前硬件环境的架构是否一致。

- 确定引入的`.a`文件是否齐全，有些库存在不明显的依赖。

##### 引入头文件`openssl`报错

编译`libimobiledevice`的时候引入了`openssl`但是`xcode`不存在这个库，所以手动导入并且修改了一些头文件配置。