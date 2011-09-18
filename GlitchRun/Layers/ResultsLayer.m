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

#import "ResultsLayer.h"
#import "GameManager.h"

@implementation ResultsLayer

- (id)init
{
    self = [super init];
    if (self) 
    {
        NSString *fntFile = @"ArialRounded-24.fnt";
        CGSize screenSize = [[CCDirector sharedDirector] winSize];

        CCMenuItem *playButton = [CCMenuItemImage 
                                  itemFromNormalImage:@"PlayButton.png" selectedImage:@"PlayButtonActive.png" 
                                  target:self selector:@selector(playButtonPressed:)];
        
        playButton.position = CGPointMake(screenSize.width - 80, 80);
        
        CCMenu *mainMenu = [CCMenu menuWithItems:playButton, nil];
        mainMenu.position = CGPointZero;
        [self addChild:mainMenu];
        
        float score = [GameManager sharedGameManager].lastDistanceRan;
        float hiscore = [GameManager sharedGameManager].hiScore;
        
        if (score > hiscore)
        {
            [GameManager sharedGameManager].hiScore = score;
            CCLabelBMFont *newHighScoreLabel = [CCLabelBMFont labelWithString:@"New high score!"  fntFile:fntFile];
            newHighScoreLabel.position = ccp(20 + newHighScoreLabel.contentSize.width/2,  screenSize.height - 40); 
            [self addChild:newHighScoreLabel];
            hiscore = score;
            
        }
        
        CCLabelBMFont *scoreLabel = [CCLabelBMFont labelWithString:[NSString stringWithFormat:@"Final distance: %.2fm", score]  fntFile:fntFile];
        scoreLabel.position = ccp(20 + scoreLabel.contentSize.width/2,  screenSize.height - 80); 
        [self addChild:scoreLabel];

        CCLabelBMFont *hiScoreLabel = [CCLabelBMFont labelWithString:[NSString stringWithFormat:@"High score: %.2fm", hiscore] fntFile:fntFile];
        hiScoreLabel.position = ccp(20 + hiScoreLabel.contentSize.width/2,  screenSize.height - 120); 
        [self addChild:hiScoreLabel];
        
    }
    
    return self;
}


-(void)playButtonPressed:(id)sender
{
    [[GameManager sharedGameManager] runScene:GameSceneRun];
}



@end
