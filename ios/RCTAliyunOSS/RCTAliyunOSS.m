//
//  RCTAliyunOSS.m
//  RCTAliyunOSS
//
//  Created by 李京生 on 2016/10/26.
//  Copyright © 2016年 lesonli. All rights reserved.
//

#import "RCTAliyunOSS.h"
#import "RCTLog.h"
#import "OSSService.h"


@implementation RCTAliyunOSS{
    
    OSSClient *client;
 
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"uploadProgress", @"downloadProgress"];
}

// get local file dir which is readwrite able
- (NSString *)getDocumentDirectory {
    NSString * path = NSHomeDirectory();
    NSLog(@"NSHomeDirectory:%@",path);
    NSString * userName = NSUserName();
    NSString * rootPath = NSHomeDirectoryForUser(userName);
    NSLog(@"NSHomeDirectoryForUser:%@",rootPath);
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * documentsDirectory = [paths objectAtIndex:0];
    return documentsDirectory;
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(enableOSSLog) {
    // 打开调试log
    [OSSLog enableLog];
    RCTLogInfo(@"OSSLog: 已开启");
}
// 由阿里云颁发的AccessKeyId/AccessKeySecret初始化客户端。
// 明文设置secret的方式建议只在测试时使用，
// 如果已经在bucket上绑定cname，将该cname直接设置到endPoint即可
RCT_EXPORT_METHOD(initWithKey:(NSString *)AccessKey
                  SecretKey:(NSString *)SecretKey
                  securityToken:(NSString *)securityToken
                  Endpoint:(NSString *)Endpoint){
    
    id<OSSCredentialProvider> credential = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:AccessKey secretKeyId:SecretKey securityToken:securityToken];
    
    //bucket上绑定cname，将该cname直接设置到endPoint
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 3; // 网络请求遇到异常失败后的重试次数
    conf.timeoutIntervalForRequest = 30; // 网络请求的超时时间
    conf.timeoutIntervalForResource = 24 * 60 * 60; // 允许资源传输的最长时间
    NSString *endpoint = Endpoint;
    
    client = [[OSSClient alloc] initWithEndpoint:endpoint credentialProvider:credential clientConfiguration:conf];
}

//通过签名方式初始化，需要服务端实现签名字符串，签名算法参考阿里云文档
RCT_EXPORT_METHOD(initWithSigner:(NSString *)AccessKey
                  Signature:(NSString *)Signature
                  Endpoint:(NSString *)Endpoint){
    
    // 自实现签名，可以用本地签名也可以远程加签
    id<OSSCredentialProvider> credential1 = [[OSSCustomSignerCredentialProvider alloc] initWithImplementedSigner:^NSString *(NSString *contentToSign, NSError *__autoreleasing *error) {
        //NSString *signature = [OSSUtil calBase64Sha1WithData:contentToSign withSecret:@"<your secret key>"];
        if (Signature != nil) {
            *error = nil;
        } else {
            // construct error object
            *error = [NSError errorWithDomain:Endpoint code:OSSClientErrorCodeSignFailed userInfo:nil];
            return nil;
        }
        //return [NSString stringWithFormat:@"OSS %@:%@", @"<your access key>", signature];
        return [NSString stringWithFormat:@"OSS %@:%@", AccessKey, Signature];
    }];

    
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 1;
    conf.timeoutIntervalForRequest = 30;
    conf.timeoutIntervalForResource = 24 * 60 * 60;
    
    client = [[OSSClient alloc] initWithEndpoint:Endpoint credentialProvider:credential1 clientConfiguration:conf];
}

//异步下载
RCT_REMAP_METHOD(downloadObjectAsync, bucketName:(NSString *)bucketName objectKey:(NSString *)objectKey updateDate:(NSString *)updateDate resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    OSSGetObjectRequest *request = [OSSGetObjectRequest new];
    // required
    request.bucketName = bucketName;
    request.objectKey = objectKey;
    // optional
    request.downloadProgress = ^(int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        NSLog(@"%lld, %lld, %lld", bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
        [self sendEventWithName: @"downloadProgress" body:@{@"everySentSize":[NSString stringWithFormat:@"%lld",bytesWritten],
                                                          @"currentSize": [NSString stringWithFormat:@"%lld",totalBytesWritten],
                                                          @"totalSize": [NSString stringWithFormat:@"%lld",totalBytesExpectedToWrite]}];
    };
    NSString *docDir = [self getDocumentDirectory];
    NSLog(objectKey);
    NSURL *url = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:objectKey]];
    request.downloadToFileURL = url;
    OSSTask *getTask = [client getObject:request];
    [getTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            NSLog(@"download object success!");
            OSSGetObjectResult *result = task.result;
            NSLog(@"download dota length: %lu", [result.downloadedData length]);
            resolve(url.absoluteString);
        } else {
            NSLog(@"download object failed, error: %@" ,task.error);
            reject(nil, @"download object failed", task.error);
        }
        return nil;
    }];
}

//异步上传
RCT_REMAP_METHOD(uploadObjectAsync, bucketName:(NSString *)BucketName
                  SourceFile:(NSString *)SourceFile
                  OssFile:(NSString *)OssFile
                  UpdateDate:(NSString *)UpdateDate
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
    
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    
    // required fields
    put.bucketName = BucketName;
    put.objectKey = OssFile;
    //NSString * docDir = [self getDocumentDirectory];
    //put.uploadingFileURL = [NSURL fileURLWithPath:[docDir stringByAppendingPathComponent:@"file1m"]];
    put.uploadingFileURL = [NSURL fileURLWithPath:SourceFile];
    NSLog(@"uploadingFileURL: %@", put.uploadingFileURL);
    // optional fields
    put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
        [self sendEventWithName: @"uploadProgress" body:@{@"everySentSize":[NSString stringWithFormat:@"%lld",bytesSent],
                                                          @"currentSize": [NSString stringWithFormat:@"%lld",totalByteSent],
                                                          @"totalSize": [NSString stringWithFormat:@"%lld",totalBytesExpectedToSend]}];

    };
    //put.contentType = @"";
    //put.contentMd5 = @"";
    //put.contentEncoding = @"";
    //put.contentDisposition = @"";
     put.objectMeta = [NSMutableDictionary dictionaryWithObjectsAndKeys: UpdateDate, @"Date", nil];
    
    OSSTask * putTask = [client putObject:put];
    
    [putTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"objectKey: %@", put.objectKey);
        if (!task.error) {
            NSLog(@"upload object success!");
            resolve(@YES);
        } else {
            NSLog(@"upload object failed, error: %@" , task.error);
            reject(@"-1", @"not respond this method", nil);
        }
        return nil;
    }];
}



@end
