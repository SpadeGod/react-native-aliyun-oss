/**
 * @flow
 */
'use strict';

import {
  NativeModules,
  NativeAppEventEmitter,
  NativeEventEmitter,
  Platform
} from 'react-native';
const NativeAliyunOSS = NativeModules.AliyunOSS;
const UPLOAD_EVENT = 'uploadProgress';
const DOWNLOAD_EVENT = 'downloadProgress';

const _subscriptions = new Map();

const AliyunOSS = {
  //开启oss log
  enableOSSLog() {
    NativeAliyunOSS.enableOSSLog();
  },
  /*初始化ossclient，
  **通过AccessKey和SecretKey
  *
  */
  initWithKey(conf, EndPoint) {
    NativeAliyunOSS.initWithKey(conf.AccessKey, conf.SecretKey, conf.SecretToken, EndPoint);
  },
  /*初始化ossclient，
  **通过签名字符串，此处采用的是服务端签名
  *
  */
  initWithSigner(AccessKey, Signature, EndPoint) {
    NativeAliyunOSS.initWithSigner(AccessKey, Signature, EndPoint);
  },
  /*异步上传文件
  **bucketName
  *sourceFile:源文件路径，例如:/User/xx/xx/test.jpg
  *ossFile:目标路径，例如:文件夹/文件名  test/test.jpg
  *updateDate:需要和签名中用到的时间一致
  */
  uploadObjectAsync(conf) {
    return NativeAliyunOSS.uploadObjectAsync(
      conf.bucketName,
      conf.sourceFile,
      conf.ossFile,
      conf.updateDate);
  },

  downloadObjectAsync(conf) {
    return NativeAliyunOSS.downloadObjectAsync(
      conf.bucketName,
      conf.ossFile,
      conf.updateDate);
  },

  /*监听上传和下载事件，
  **返回对象3个属性
  *everySentSize:每次上传／下载字节
  *currentSize:当前所需上传／下载字节
  *totalSize:总字节
  */
  addEventListener(type, handler) {
    var listener;
    if (Platform.OS === 'ios') {
      const Emitter = new NativeEventEmitter(NativeAliyunOSS);
      if (type === UPLOAD_EVENT) {
        listener = Emitter.addListener(
          'uploadProgress',
          (uploadData) => {
            handler(uploadData);
          }
        );
      } else if (type === DOWNLOAD_EVENT) {
        listener = Emitter.addListener(
          'downloadProgress',
          (downloadData) => {
            handler(downloadData);
          }
        );
      } else {
        return false;
      }
    }
    else {
      if (type === UPLOAD_EVENT) {
        listener = NativeAppEventEmitter.addListener(
          'uploadProgress',
          (uploadData) => {
            handler(uploadData);
          }
        );
      } else if (type === DOWNLOAD_EVENT) {
        listener = NativeAppEventEmitter.addListener(
          'downloadProgress',
          (downloadData) => {
            handler(downloadData);
          }
        );
      } else {
        return false;
      }
    }
    _subscriptions.set(handler, listener);
  },
  removeEventListener(type, handler) {
    if (type !== UPLOAD_EVENT && type !== DOWNLOAD_EVENT) {
      return false;
    }
    var listener = _subscriptions.get(handler);
    if (!listener) {
      return;
    }
    listener.remove();
    _subscriptions.delete(handler);
  }
};

module.exports = AliyunOSS;
