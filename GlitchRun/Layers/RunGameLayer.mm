//
// Run
//
// Copyright 2011 Tiny Speck, Inc.
// Created by David Wilkinson.
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License. 
//
// See more about Glitch at http://www.glitch.com
// http://www.tinyspeck.com
//

#import "GameManager.h"
#import "RunGameLayer.h"
#import "Constants.h"
#import "Box2DSprite.h"
#import "GB2ShapeCache.h"

typedef enum
{
    GameStateNotStarted = 1,
    GameStateRunning,
    GameStateCrashed,
    GameStateGameOver
    
} GameState;

@interface RunGameLayer ()

- (void)createBodyAtLocation:(b2Vec2)location 
                        type:(b2BodyType)type
                   forSprite:(Box2DSprite *)sprite 
               fromShapeName:(NSString *)shapeName;

-(void)createBodyAtLocation:(b2Vec2)location 
                       type:(b2BodyType)type
                  forSprite:(Box2DSprite *)sprite 
                   friction:(float32)friction 
                restitution:(float32)restitution 
                    density:(float32)density 
                      isBox:(BOOL)isBox;

-(void)updateObstacles;
-(CGPoint)convertWorldToScreen:(b2Vec2)worldPos;
-(void)setStatusLabelText:(NSString *)text;
-(void)crash;


@property (retain, nonatomic) Box2DSprite *jumper;
@property (assign, nonatomic) float32 jumperOffset;
@property (assign, nonatomic) b2Body *ground;
@property (assign, nonatomic) ccTime jumpRequest;
@property (retain, nonatomic) NSMutableArray *obstacles;
@property (assign, nonatomic) float32 minDistanceToNextObstacle;
@property (assign, nonatomic) float32 variantDistanceToNextObstacle;
@property (assign, nonatomic) float32 maxLinearVelocity;
@property (assign, nonatomic) float32 lastObstacleLocation;
@property (retain, nonatomic) CCLabelBMFont *statusLabel;
@property (assign, nonatomic) GameState gameState;

@end


@implementation RunGameLayer

@synthesize jumper = _jumper;
@synthesize jumperOffset = _jumperOffset;
@synthesize ground = _ground;
@synthesize jumpRequest = _jumpRequest;
@synthesize obstacles = _obstacles;
@synthesize minDistanceToNextObstacle = _minDistanceToNextObstacle;
@synthesize variantDistanceToNextObstacle = _variantDistanceToNextObstacle;
@synthesize maxLinearVelocity = _maxLinearVelocity;
@synthesize lastObstacleLocation = _lastObstacleLocation;
@synthesize statusLabel = _statusLabel;
@synthesize gameState = _gameState;

- (id)init
{
    self = [super init];
    if (self) 
    {
        self.gameState = GameStateNotStarted;
        
        CGSize screenSize = [[CCDirector sharedDirector] winSize];
        
        self.obstacles = [NSMutableArray arrayWithCapacity:20];
        
        self.jumperOffset = screenSize.width/4;
        
        // Define the gravity vector.
		b2Vec2 gravity;
		gravity.Set(0.0f, -10.0f);
		bool doSleep = true;
        world = new b2World(gravity, doSleep);
        world->SetContinuousPhysics(true);
        
        // Define the ground body.
		b2BodyDef groundBodyDef;
		groundBodyDef.position.Set(0, 0); // bottom-left corner
        groundBodyDef.type = b2_staticBody;
		
		self.ground = world->CreateBody(&groundBodyDef);
		
		// Define the ground box shape.
		b2PolygonShape groundBox;		
		
		// Define the ground as being a few screen widths wide, and we'll move it to follow us
        // That way, we'll never run out of space
        CGFloat w = screenSize.width * 5/PTM_RATIO;
		groundBox.SetAsEdge(b2Vec2(-w/2, 0.5), b2Vec2(w/2, 0.5));
		self.ground->CreateFixture(&groundBox, 0);
        
        self.jumper = [Box2DSprite spriteWithSpriteFrameName:@"Circle.png"];

        CGSize spriteSize = self.jumper.contentSize; 
        b2Vec2 jumperPos = b2Vec2(0, 0.6); 

        [self createBodyAtLocation:jumperPos
                              type:b2_dynamicBody
                         forSprite:self.jumper 
                          friction:0.02 
                       restitution:0.2 
                           density:10 
                             isBox:NO];
        
        b2Body *jumperBody = self.jumper.body;
        jumperBody->SetFixedRotation(YES);
        
        CGPoint screenPos = [self convertWorldToScreen:jumperPos];
        self.jumper.position = ccp(screenPos.x + spriteSize.width/2, screenPos.y + spriteSize.height/2);
        [self addChild:self.jumper z:20];

        
        self.isTouchEnabled = YES;
        self.minDistanceToNextObstacle = 6.0;
        self.variantDistanceToNextObstacle = 10.0;
        self.maxLinearVelocity = 4.0;
        
        self.statusLabel = [CCLabelBMFont labelWithString:@"" fntFile:@"Arial-16.fnt"];
        [self addChild:self.statusLabel z:100];
        [self setStatusLabelText:@"Touch screen to start"];
    }
    
    return self;
}

-(void)dealloc
{
    [_jumper release];
    _jumper = nil;
    
    [_obstacles release];
    _obstacles = nil;
    
    [_statusLabel release];
    _statusLabel = nil;
    
    if (world)
    {
        delete world;
        world = NULL;   
    }
    
    [super dealloc];
}


-(CGFloat)jumperDistance
{
    b2Body *jumperBody = self.jumper.body;
    b2Vec2 position = jumperBody->GetPosition();
    return position.x;
}

-(void)setStatusLabelText:(NSString *)text
{
    CGSize screenSize = [[CCDirector sharedDirector] winSize];
    [self.statusLabel setString:text];
    self.statusLabel.position = ccp(screenSize.width - self.statusLabel.contentSize.width/2 - 10,  screenSize.height - 20); 
}

- (void)createBodyAtLocation:(b2Vec2)location 
                        type:(b2BodyType)type
                   forSprite:(Box2DSprite *)sprite 
                    friction:(float32)friction 
                 restitution:(float32)restitution 
                     density:(float32)density 
                       isBox:(BOOL)isBox
{
    b2BodyDef bodyDef;
    bodyDef.type = type;
    bodyDef.position = location;
    bodyDef.allowSleep = false;
    
    b2Body *body = world->CreateBody(&bodyDef); 
    body->SetUserData(sprite);
    sprite.body = body;
    
    b2FixtureDef fixtureDef;
    if (isBox) 
    {
        b2PolygonShape shape;
        shape.SetAsBox(sprite.contentSize.width/2/PTM_RATIO,
                       sprite.contentSize.height/2/PTM_RATIO);
        fixtureDef.shape = &shape;
    } 
    else 
    {
        b2CircleShape shape;
        shape.m_radius = sprite.contentSize.width/2/PTM_RATIO;
        fixtureDef.shape = &shape;
    }
    
    fixtureDef.density = density;
    fixtureDef.friction = friction;
    fixtureDef.restitution = restitution;
    body->CreateFixture(&fixtureDef);
}

- (void)createBodyAtLocation:(b2Vec2)location 
                        type:(b2BodyType)type
                   forSprite:(Box2DSprite *)sprite 
                    fromShapeName:(NSString *)shapeName 
{
    b2BodyDef bodyDef;
    bodyDef.type = type;
    bodyDef.position = location;
    bodyDef.allowSleep = false;
    
    b2Body *body = world->CreateBody(&bodyDef); 
    body->SetUserData(sprite);
    sprite.body = body;
    
    [[GB2ShapeCache sharedShapeCache] addFixturesToBody:body forShapeName:shapeName];
    [sprite setAnchorPoint:[[GB2ShapeCache sharedShapeCache] anchorPointForShape:shapeName]];
}

-(BOOL)canJump
{
    // Are we touching a (reasonably) horizontal surface?
    
    b2Body *jumper = self.jumper.body;
    
    BOOL canJump = NO;
    for (b2ContactEdge* ce = jumper->GetContactList(); ce; ce = ce->next)
    {
        b2Contact* c = ce->contact;
        if (c->IsTouching())
        {
            b2WorldManifold worldManifold;
            c->GetWorldManifold(&worldManifold);
            
            b2Vec2 normal = worldManifold.normal;
            
            b2Body *bodyA = c->GetFixtureA()->GetBody();
            if (bodyA == jumper)
            {
                normal = b2Vec2(-normal.x, -normal.y);
            }
            
            // Simplistic approach
            if (normal.y > normal.x)
            {
                canJump = YES;
            }
        }
    } 
    
    return canJump;
}


-(void)jump
{
    CCLOG(@"Jump!");
    b2Body *jumperBody = self.jumper.body;
    
    b2Vec2 impulse = b2Vec2(0.1, 40.0);
    b2Vec2 bodyCenter = jumperBody->GetWorldCenter();
    jumperBody->ApplyLinearImpulse(impulse, bodyCenter);  
}


-(void) update:(ccTime)deltaTime
{ 
    CGSize screenSize = [[CCDirector sharedDirector] winSize];
    GameState state = self.gameState;
    
    b2Body *jumperBody = self.jumper.body;
    b2Vec2 jumperPosition = jumperBody->GetPosition();
    CGFloat jumperX = jumperPosition.x;
    
    int32 velocityIterations = 8;
    int32 positionIterations = 2;
    
    // Pending jump?
    if (state == GameStateRunning && self.jumpRequest > 0)
    {
        // There is a pending jump. Decrement the timer.
        self.jumpRequest = self.jumpRequest - deltaTime;
        if ([self canJump])
        {
            [self performSelectorOnMainThread:@selector(jump) withObject:nil waitUntilDone:NO];
            self.jumpRequest = -1;
        }
    }
    
    if (state != GameStateGameOver)
    {
        world->Step(deltaTime, velocityIterations, positionIterations);
        world->ClearForces();
        
        for (b2Body* b = world->GetBodyList(); b; b = b->GetNext())
        {
            if (b->GetUserData() != NULL) 
            {
                CCSprite *ccs = (CCSprite*)b->GetUserData();
                // We're moving our frame of reference to keep the jumper in the same position on screen
                ccs.position = CGPointMake( (b->GetPosition().x - jumperX) * PTM_RATIO + screenSize.width/2 - self.jumperOffset, b->GetPosition().y * PTM_RATIO);
                ccs.rotation = -1 * CC_RADIANS_TO_DEGREES(b->GetAngle());
            }	
        }
        // Adjust the ground to stay beneath our feet
        b2Vec2 pos = b2Vec2(jumperX - (screenSize.width/2 - self.jumperOffset)/PTM_RATIO, 0);
        self.ground->SetTransform(pos, self.ground->GetAngle());
    }
    
    // Keep on movin'
    if (self.gameState == GameStateRunning)
    {
        b2Vec2 v = jumperBody->GetLinearVelocity();

        if (v.x < self.maxLinearVelocity && [self canJump])
        {
            b2Vec2 impulse = b2Vec2(0.6, 0);
            b2Vec2 bodyCenter = jumperBody->GetWorldCenter();
            jumperBody->ApplyLinearImpulse(impulse, bodyCenter);  
            v = jumperBody->GetLinearVelocity();
        }

        [self updateObstacles];
        if (v.x <= 0.0)
        {
            // We've stopped or are going backwards
            [self crash];
        }
    }
    
    if (self.gameState != GameStateNotStarted)
    {
        [self setStatusLabelText:[NSString stringWithFormat:@"Distance: %.2fm", self.jumperDistance]];
    }
}

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event
{
    switch (self.gameState)
    {
        case GameStateNotStarted:
            self.gameState = GameStateRunning;
            break;
            
        case GameStateRunning:
            if ([self canJump])
            {
                [self jump];
            }
            else
            {
                // If we're not quite on the ground when the user taps the screen, we buffer the jump request
                // and jump when we land - this makes the game feel more responsive
                self.jumpRequest = kJumpBufferTime;
            }
            break;
            
        case GameStateCrashed:
            // Do nothing
            break;
            
        case GameStateGameOver:
            [[GameManager sharedGameManager] runScene:GameSceneResults];
            break;
    }
    
	return YES;
}

-(void)registerWithTouchDispatcher
{
	[[CCTouchDispatcher sharedDispatcher] addTargetedDelegate:self priority:0 swallowsTouches:YES];
}

/*
 * Dispose of old obstacles and determine whether to add a new one.
 */
-(void)updateObstacles
{
    CGSize screenSize = [[CCDirector sharedDirector] winSize];

    b2Body *jumperBody = self.jumper.body;
    b2Vec2 jumperPosition = jumperBody->GetPosition();
    float32 jumperX = jumperPosition.x;
    BOOL obstacleDestroyed = NO;
    
    while ([self.obstacles count] > 0)
    {
        Box2DSprite *sprite = [self.obstacles objectAtIndex:0];
        b2Vec2 pos = sprite.body->GetPosition();
        if (jumperX - pos.x > 2 * screenSize.width / PTM_RATIO)  // More than a couple of screen widths away, we can dispose of it
        {
            world->DestroyBody(sprite.body);
            [self removeChild:sprite cleanup:YES];
            [self.obstacles removeObject:sprite];
            obstacleDestroyed = YES;
        }
        else
        {
            // They're all closer from here on
            break;
        }
    }
    
    // And do we need a new one?
    if ([self.obstacles count] < 20) // Throttle the number of obstacles we have on the go at any one time
    {
        //Create a new obstacle
        NSString *obstacleName = @"Circle.png";
        switch (arc4random() % 4)
        {
            case 0:
                obstacleName = @"Circle.png";
                break;
                
            case 1: 
                obstacleName = @"Square.png";
                break;

            case 2: 
                obstacleName = @"SmallSquare.png";
                break;

            case 3: 
                obstacleName = @"Triangle.png";
                break;
        }
        
        Box2DSprite *obstacle = [Box2DSprite spriteWithSpriteFrameName:obstacleName];
        CGSize spriteSize = obstacle.contentSize;

        float32 newX = self.lastObstacleLocation + self.minDistanceToNextObstacle + ((float32)(arc4random() % (int)(self.variantDistanceToNextObstacle * 100)))/100;
        b2Vec2 pos = b2Vec2(newX, 0.5 + (spriteSize.height/2)/PTM_RATIO);
        CGPoint screenPos = [self convertWorldToScreen:pos];
        
        obstacle.position = ccp(screenPos.x + spriteSize.width/2, screenPos.y + spriteSize.height/2);
        [self addChild:obstacle z:10];
        [self.obstacles addObject:obstacle];
        
        NSString *shapeName = [obstacleName stringByDeletingPathExtension];
        
        [self createBodyAtLocation:pos
                              type:b2_staticBody
                         forSprite:obstacle 
                     fromShapeName:shapeName];
        
        self.lastObstacleLocation = newX;
    }
    
    if (obstacleDestroyed)
    {
        // We've destroyed on obstacle
        // Update the parameters to make the game progressively harder with each obstacle
        if (self.variantDistanceToNextObstacle > 2)
        {
            self.variantDistanceToNextObstacle -= 0.5;
        }
        else
        {
            // We've reduced the variant part as much as we are prepared to go, so now reduce the minimum distance between obstacles
            if (self.minDistanceToNextObstacle > 2)
            {
                self.minDistanceToNextObstacle -= 0.2;                
            }
        }
        self.maxLinearVelocity += 0.01;
    }
}

-(void)crash
{
    CCLOG(@"CRASH!");
    self.gameState = GameStateCrashed;
    [self performSelector:@selector(gameOver) withObject:nil afterDelay:2.0];
}

-(void)gameOver
{
    CCLabelBMFont *gameOver = [CCLabelBMFont labelWithString:@"GAME OVER" fntFile:@"ArialRounded-48.fnt"];
    CGSize screenSize = [[CCDirector sharedDirector] winSize];
    gameOver.position = ccp(screenSize.width/2,  screenSize.height - 100); 
    [self addChild:gameOver];
    self.gameState = GameStateGameOver;
    [GameManager sharedGameManager].lastDistanceRan = self.jumperDistance;
}


-(CGPoint)convertWorldToScreen:(b2Vec2)worldPos
{
    // Screen is drawn relative to the jumper
    CGSize screenSize = [[CCDirector sharedDirector] winSize];
    
    b2Body *jumperBody = self.jumper.body;
    b2Vec2 jumperPosition = jumperBody->GetPosition();
    float32 jumperX = jumperPosition.x;

    CGPoint screenPos = CGPointMake((worldPos.x - jumperX) * PTM_RATIO + screenSize.width/2 - self.jumperOffset, worldPos.y * PTM_RATIO);
    return screenPos;
}

@end
