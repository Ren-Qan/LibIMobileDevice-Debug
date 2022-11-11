# LibIMobileDevice-Debug
debug libimobiledevice components with xcode

#### 踩坑日记

前提：因为俺有两台的电脑，处理器分别为 `Apple` 和 `Inter`。

##### 编译依赖库的报错：

- 这个实在太多了整理整理在补充。

##### 编译报错`Undefined symbols for architecture x86_64`：

- 在`已经导入静态库的前提`下还是编译报错，说明编译出来的`.a`文件不支持`x86_64`，所以需要引用当前适合的静态库，为了图方便所以哥们直接在工程中引入了两种架构的静态库。

- 当导入一个`.a文件`编译时候却报错`Undefined symbols`，也有可能需要导入其他的`.a`，例如导入`libimobiledevice-1.0.a`还需要导入`libssl.a` `libcrypto.a` `libusbmuxd.a` `libcurl.tbd`

