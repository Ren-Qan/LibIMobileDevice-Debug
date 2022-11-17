# LibIMobileDevice-Debug
`debug libimobiledevice components source code with xcode`

- 纯测试工程，里面可能有奇怪的变量命名完全图方便。
- 因为没人看且没开发完，所以先不正经等开发完成了在正经（吧）

#### libimobiledevice编译踩坑篇

- 前提：因为俺有两台的电脑，处理器分别为 `Apple(arm64)` 和 `Intel(x86)`。

##### 编译依赖库的报错：

- 在编译源码的时候一定得先下载好依赖库`openssl`啥的。直接无脑`brew install xxxxx`

- `libplist` 执行 `./autogen.sh`时候报错` Could not link test program to Python.` 哥们直接抄作业`./autogen.sh CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=10.11" --without-cython`。[参考](https://github.com/zqqf16/SYM/blob/master/SYM/Device/build.sh)(感谢大佬的源码，学习了不少)。

- 编译`libusbmuxd`的时候老是报错 `No package 'libimobiledevice-glue-1.0' found`，其实是`.pc`文件没找到，所以咱们又直接抄作业仿照`brew install xxxx`库的文件格式给他造一个出来，然后利用 `export PKG_CONFIG_PATH=/xxx/xxx/xx `填上路径，应该就好了。

- 还有一些来着暂时没想到。嘿嘿嘿

##### 编译报错`Undefined symbols for architecture x86_64`：

- 注意制作的`.a`文件支持的架构与当前硬件环境的架构是否一致。

- 确定引入的`.a`文件是否齐全，有些库存在不明显的依赖。

- 对应不同的`CPU`架构，切换不同的`Library Search Paths`的查找顺序

##### 引入头文件`openssl`报错

- 编译`libimobiledevice`的时候引入了`openssl`但是`xcode`不存在这个库，所以手动导入并且修改了一些头文件配置。 

##### 接入`.a`后接口不能正常执行

- 需要取消掉`APP`的`沙盒机制`



#### 致谢：

感谢各位开源的作者（被我抄作业的同学）`因为还没开发完等开发完了链接补上。`

