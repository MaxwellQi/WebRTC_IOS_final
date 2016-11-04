# WebRTC_IOS_final
The latest webrtc library integration


## 说明

### 对项目的说明

这个项目是使用c++版本的socket.io库；WebRTC使用的是OC版本的。在WebRTC操作类中调用socket.io操作类中的方法，进而实现VOIP通话。

这个项目主要是一个资源项目，可以作为以后用到这连个库的备用。

这个项目包含的内容有：

* `WebRTC` 的动态库：WebRTC.framework
* Socket.io 的操作类：在socketIO目录中
* WebRTC 的操作类： 在webrtc目录中

### 使用项目中的内容，你需要提前做的事情

* 集成 socket.io 库（c++版本）  具体可参照 [Socket.io_CPP](https://github.com/MaxwellQi/Socket.io_CPP)
* 由于 WebRTC.framework 是一个动态库，因此集成动态库的时候有些注意事项。具体可参照 [ios使用动态库](http://foggry.com/blog/2014/06/12/wwdc2014zhi-iosshi-yong-dong-tai-ku/)
* WebRTC.framework 是一个最新的WebRTC库，不是libjingle那个版本的。


### 其它

关于VOIP通信，即 socket.io 和 WebRTC 的原理和详细说明以及注意事项，可以参考博客 [WebRTC通信的原理](https://github.com/MaxwellQi/summ-webrtc-knowledge)


### MaxwellQi

[More about me](https://maxwellqi.github.io/about-me/)