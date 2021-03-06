//
//
//  HCSnakeRender.m
//  OpenGLDemo
//
//  Created by 霍橙 on 2021/6/21.
//  
//
    

#import "HCSnakeRender.h"
#import "HCGLTextureNode.h"
#import "HCGLTextureManager.h"
#import "HCGLSnakeDrawer.h"
#import "GameConfig.h"

@interface HCSnakeRender ()

@property(nonatomic, strong) HCGLTexture *headTexture;
@property(nonatomic, strong) HCGLTexture *bodyTexture;

@property(nonatomic, assign) NSUInteger loadTextureIndex;

@end

@implementation HCSnakeRender

- (void)render {
    [self loadTexture];
    HCLinkList *linkList = self.drawListWithBodyData;
    [self.glkView.snakeDrawerManager updateDataWithKey:self.snake.snakeIdString dataList:linkList textureArray:self.textureArray];
}

- (HCLinkList *)drawListWithBodyData {
    HCLinkList *snakeDrawList = HCLinkList.new;
    for (NSUInteger i = 0;i < self.snake.length;i += NODE_INDEX_INTERVAL + 1) {
        HCSnakeNode *bodyNode = self.snake.bodyNodeArray[i];
        HCGLTextureNode *drawBodyNode = [HCGLTextureNode.alloc initWithPosition:bodyNode.center size:HCGLSizeMake(self.snake.width * 2, self.snake.width * 2) direction:bodyNode.direction];
        drawBodyNode.texture = self.bodyTexture;
        [drawBodyNode calculateVertexArray];
        [snakeDrawList addNode:[HCLinkNode nodeWithValue:drawBodyNode]];
    }
    HCSnakeNode *headNode = self.snake.headNode;
    HCGLTextureNode *drawHeadNode = [HCGLTextureNode.alloc initWithPosition:headNode.center size:HCGLSizeMake(self.snake.width * 2, self.snake.width * 2) direction:self.snake.direction];
    drawHeadNode.texture = self.headTexture;
    [drawHeadNode calculateVertexArray];
    [snakeDrawList addNode:[HCLinkNode nodeWithValue:drawHeadNode]];
    return snakeDrawList;
}

- (void)loadTexture {
    if (self.loadTextureIndex == 0) {
        NSString *headUrl = [self.snake.headSkin getSkinWithTimestamp:self.dataManager.timestamp];
        self.headTexture = [self loadTextureWithUrl:headUrl];
        self.headTexture.textureIndex = 0;
        
        NSString *bodyUrl = [self.snake.bodySkin getSkinWithTimestamp:self.dataManager.timestamp];
        self.bodyTexture = [self loadTextureWithUrl:bodyUrl];
        self.bodyTexture.textureIndex = 1;
    }
    self.loadTextureIndex ++;
    if (self.loadTextureIndex == 10) {
        self.loadTextureIndex = 0;
    }
}

- (HCGLTexture *)loadTextureWithUrl:(NSString *)url {
    HCGLTexture *texture = [self.glkView.textureManager textureWithUrl:url];
    texture.isRepeat = NO;
    [texture loadTexture];
    return texture;
}

- (NSArray *)textureArray {
    return @[@(self.headTexture.name), @(self.bodyTexture.name)];
}

@end
