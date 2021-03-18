//
//  HCGLKView01.m
//  OpenGLDemo
//
//  Created by wepie on 2021/3/16.
//

#import "HCGLKView01.h"
#import <GLKit/GLKit.h>

@interface HCGLKView01 ()

@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, strong) CAEAGLLayer *eagLayer;
@property (nonatomic, assign) GLuint program;

@property (nonatomic, assign) GLuint renderBuffer;
@property (nonatomic, assign) GLuint frameBuffer;

@end

@implementation HCGLKView01

+ (Class)layerClass {
    return CAEAGLLayer.class;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setupCAEAGLLayer];
    [self setupGLContext];
    [self destoryRenderAndFrameBuffer];
    [self setupRenderAndFrameBuffer];
    [self setupGL];
    [self setupProgram];
    [self render];
}

- (void)setupGLContext {
    self.context = [EAGLContext.alloc initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:_context];
}

- (void)setupCAEAGLLayer {
    self.eagLayer = (CAEAGLLayer *)self.layer;
    //设置缩放比例
    self.eagLayer.contentsScale = UIScreen.mainScreen.scale;
    self.eagLayer.opaque = YES;
    self.eagLayer.drawableProperties = @{
        kEAGLDrawablePropertyRetainedBacking : @(NO),
        kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8,
    };
}

- (GLuint)setupTexture {
    //转化uiimage为cgimageref
    CGImageRef textureImage = [UIImage imageNamed:@"player"].CGImage;
    size_t width = CGImageGetWidth(textureImage);
    size_t height = CGImageGetHeight(textureImage);
    
    //绘制图片
    void *textureData = malloc(width * height * 4);
    CGContextRef textureContext = CGBitmapContextCreate(textureData, width, height, 8, width * 4, CGImageGetColorSpace(textureImage), kCGImageAlphaPremultipliedLast);
    //翻转坐标系
    CGContextTranslateCTM(textureContext, 0, height);
    CGContextScaleCTM(textureContext, 1, -1);
    //绘制
    CGContextDrawImage(textureContext, CGRectMake(0, 0, width, height), textureImage);
    //释放内存
    CGContextRelease(textureContext);
    
    //生成纹理
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (float)width, (float)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, textureData);
    
    //设置映射方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    free(textureData);
    
    return textureID;
}

- (void)destoryRenderAndFrameBuffer {
    if (_renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
        _renderBuffer = 0;
    }
    if (_frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
        _frameBuffer = 0;
    }
}

- (void)setupRenderAndFrameBuffer {
    //绑定渲染缓存到layer上
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eagLayer];

    //将渲染缓存绑定到帧缓存上
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
}

- (void)setupGL {
    glClearColor(0, 1, 1, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    //设置混合模式，去除透明底部
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    CGFloat scale = UIScreen.mainScreen.scale;
    glViewport(self.frame.origin.x * scale, self.frame.origin.y * scale, self.frame.size.width * scale, self.frame.size.height * scale);
}

- (void)setupProgram {
    //创建一个管线
    self.program = glCreateProgram();
    //生成一个顶点着色器
    NSString *vertFile = [NSBundle.mainBundle pathForResource:@"Shader" ofType:@"vsh"];
    GLuint vertShader = [self compileShader:vertFile withShaderType:GL_VERTEX_SHADER];
    //生成一个片段着色器
    NSString *fragFile = [NSBundle.mainBundle pathForResource:@"Shader" ofType:@"fsh"];
    GLuint fragShader = [self compileShader:fragFile withShaderType:GL_FRAGMENT_SHADER];

    //将两个着色器挂载到管线上
    glAttachShader(self.program, vertShader);
    glAttachShader(self.program, fragShader);

    //链接Program
    glLinkProgram(self.program);
    //检查是否链接成功
    GLint linkSuccess;
    glGetProgramiv(self.program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {//输出错误信息
        GLchar messages[256];
        glGetProgramInfoLog(self.program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
    } else {
        NSLog(@"link OK");
        //执行Program
        glUseProgram(self.program);
    }
    //释放两个着色器 参考https://www.jianshu.com/p/bf1aac8bda9a
    if (vertShader) {
        glDetachShader(self.program, vertShader);//解除绑定
        glDeleteShader(vertShader);//删除着色器
    }
    if (fragShader) {
        glDetachShader(self.program, fragShader);//解除绑定
        glDeleteShader(fragShader);//删除着色器
    }
}

- (void)render {
    if (self.program == 0) {
        return;
    }
    
    GLfloat attrArray[] = {
        -0.5f, 0.5f, 0.0f,     0.0f, 1.0f,
        0.5f, 0.5f, 0.0f,     1.0f, 1.0f,
        -0.5f, -0.5f, 0.0f,    0.0f, 0.0f,
        0.5f, 0.5f, 0.0f,      1.0f, 1.0f,
        0.5f, -0.5f, 0.0f,    1.0f, 0.0f,
        -0.5f, -0.5f, 0.0f,     0.0f, 0.0f,
    };
    
    //生成缓存标识符
    GLuint attrBuffer;
    glGenBuffers(1, &attrBuffer);
    //绑定缓存
    glBindBuffer(GL_ARRAY_BUFFER, attrBuffer);
    //将数据存入缓存
    glBufferData(GL_ARRAY_BUFFER, sizeof(attrArray), attrArray, GL_DYNAMIC_DRAW);
    
    //获取position变量
    GLuint position = glGetAttribLocation(self.program, "position");
    //传入position变量值
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (GLfloat *)NULL + 0);
    //启用缓存
    glEnableVertexAttribArray(position);
    
    GLuint textCoor = glGetAttribLocation(self.program, "textCoordinate");
    glVertexAttribPointer(textCoor, 2, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 5, (GLfloat *)NULL + 3);
    glEnableVertexAttribArray(textCoor);
    
    GLuint textureID = [self setupTexture];
    GLuint colorMap = glGetUniformLocation(self.program, "colorMap");
//    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, textureID);
    glUniform1i(colorMap, 0);//将colorMap赋值为GL_TEXTURE0，GL_TEXTURE0对应值为0
    
    
    glDrawArrays(GL_TRIANGLES, 0, 6);
    
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

- (GLuint)compileShader:(NSString *)filePath withShaderType:(GLenum)shaderType {

    //读取文件
    NSString *shaderString = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    const GLchar* source = (GLchar *)shaderString.UTF8String;
    //创建着色器
    GLuint shader = glCreateShader(shaderType);
    //将着色器源码加载到着色器上
    glShaderSource(shader, 1, &source, NULL);
    //运行时编译着色器
    glCompileShader(shader);
    //检查是否编译成功
    GLint compileSuccess;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {//输出错误信息
        GLchar messages[256];
        glGetShaderInfoLog(shader, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        return shader;
    }
    return shader;
}

@end
