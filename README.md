# react-native-aliyun-oss

react-native aliyun oss

# 安装
```
npm install --save react-native-aliyun-oss-cp

link libaray in your android and IOS project
```

# 兼容IPv6-Only网络

OSS移动端SDK为了解决无线网络下域名解析容易遭到劫持的问题，已经引入了HTTPDNS进行域名解析，直接使用IP请求OSS服务端。在IPv6-Only的网络下，可能会遇到兼容性问题。而APP官方近期发布了关于IPv6-only网络环境兼容的APP审核要求，为此，SDK从2.5.0版本开始已经做了兼容性处理。在新版本中，除了-ObjC的设置，还需要引入两个系统库：
```
libresolv.tbd
SystemConfiguration.framework
```

# 使用

```

import AliyunOSS from 'react-native-aliyun-oss'

AliyunOSS.enableOSSLog();
    const config = {
      AccessKey: '',  // your accessKeyId
      SecretKey: '', // your accessKeySecret
      SecretToken: '', // your securityToken
    };
    const endPoint = data.endPoint;
    // 初始化阿里云组件
    AliyunOSS.initWithKey(config, endPoint);
    // upload config
    const uploadConfig = {
      bucketName: '',  //your bucketName
      sourceFile: '', // local file path
      ossFile: '' // the file path uploaded to oss
    };
    // 上传进度
    const uploadProgress = p => console.log(p.currentSize / p.totalSize);
    // 增加上传事件监听
    AliyunOSS.addEventListener('uploadProgress', uploadProgress);
    // 执行上传
    AliyunOSS.uploadObjectAsync(uploadConfig).then((resp) => {
      // 去除事件监听
      AliyunOSS.removeEventListener('uploadProgress', uploadProgress);
      // 此处可以执行回调
      ... 
    }).catch((err)=>{
      console.log(err);
      // 执行失败回调
      ...
});

...

// download
const downloadConfig = {
      bucketName: '',
      ossFile: '' // the file path on the oss
    };
const downloadProgress = p => console.log(p.currentSize / p.totalSize);
AliyunOSS.addEventListener('downloadProgress', downloadProgress);
await AliyunOSS.downloadObjectAsync(downloadConfig).then(path => {
  console.log(path); // the local file path downloaded from oss
  AliyunOSS.removeEventListener('downloadProgress', downloadProgress);
}).catch((error) => {
  console.error(error);
});
```

# 感谢 

代码来源于原作者@lesonli

因为在使用过程中遇到一些问题，上传图片阿里云会报错 "The OSS Access Key Id you provided does not exist in our records."

初步判断是因为原作者的native层init客户端方式使用的是 OSSPlainTextAKSKPairCredentialProvider， 不传securityToken，导致阿里云鉴权出问题。（个人猜测）

改了ios和安卓底层的代码，把init方式修改成了OSSStsTokenCredentialProvider，上传成功。

原作传送门：https://github.com/lesonli/react-native-aliyun-oss 再次感谢。
