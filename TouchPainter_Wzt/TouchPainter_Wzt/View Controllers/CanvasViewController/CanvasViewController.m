//
//  CanvasViewController.m
//  Composite
//
//  Created by Carlo Chung on 9/11/10.
//  Copyright 2010 Carlo Chung. All rights reserved.
//

#import "CanvasViewController.h"
#import "Dot.h"
#import "Stroke.h"

@interface CanvasViewController ()
@property (nonatomic, assign) BOOL isTouchDrawing;

@end

@implementation CanvasViewController

@synthesize canvasView=canvasView_;
@synthesize scribble=scribble_;
@synthesize strokeColor=strokeColor_;
@synthesize strokeSize=strokeSize_;


// hook up everything with a new Scribble instance
- (void) setScribble:(Scribble *)aScribble
{
  if (scribble_ != aScribble)
  {
      scribble_ = aScribble;
    
    // add itself to the scribble as an observer for any changes to
    // its internal state
    [scribble_ addObserver:self
                forKeyPath:@"mark"
                   options:NSKeyValueObservingOptionInitial | 
                           NSKeyValueObservingOptionNew
                   context:nil];
  }
}


- (void)viewDidLoad 
{
    [super viewDidLoad];
  
    // Get a default canvas view with the factory method of the CanvasViewGenerator
    CanvasViewGenerator *defaultGenerator = [[CanvasViewGenerator alloc] init];
    [self loadCanvasViewWithGenerator:defaultGenerator];
  
    // initialize a Scribble model
    Scribble *scribble = [[Scribble alloc] init];
    [self setScribble:scribble];
  
    // setup default stroke color and size
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    CGFloat redValue = [userDefaults floatForKey:@"red"];
    CGFloat greenValue = [userDefaults floatForKey:@"green"];
    CGFloat blueValue = [userDefaults floatForKey:@"blue"];
    CGFloat sizeValue = [userDefaults floatForKey:@"size"];
  
    [self setStrokeSize:sizeValue];
    [self setStrokeColor:[UIColor colorWithRed:redValue
                                         green:greenValue
                                          blue:blueValue
                                         alpha:1.0]];
}

- (void)viewDidUnload {
  [super viewDidUnload];
  // Release any retained subviews of the main view.
  // e.g. self.myOutlet = nil;
}


- (void)dealloc {
}

#pragma mark -
#pragma mark Stroke color and size accessor methods
- (void) setStrokeSize:(CGFloat) aSize {
    // enforce the smallest size allowed
    if (aSize < 2.0) {
        strokeSize_ = 2.0;
    } else {
        strokeSize_ = aSize;
    }
}


#pragma mark -
#pragma mark Toolbar button hit method

- (IBAction) onBarButtonHit:(id)button
{
  UIBarButtonItem *barButton = button;
  
  if ([barButton tag] == 4)
  {
    [self.undoManager undo];
  }
  else if ([barButton tag] == 5)
  {
    [self.undoManager redo];
  }
}

- (IBAction) onCustomBarButtonHit:(CommandBarButton *)barButton
{
  [[barButton command] execute];
}

#pragma mark -
#pragma mark Loading a CanvasView from a CanvasViewGenerator

- (void) loadCanvasViewWithGenerator:(CanvasViewGenerator *)generator
{
    [canvasView_ removeFromSuperview];
    CGRect aFrame = CGRectMake(0, 0, iScreenWidth, iScreenHeight-iBottomToolHeight);
    CanvasView *aCanvasView = [generator canvasViewWithFrame:aFrame];
    [self setCanvasView:aCanvasView];
    NSInteger viewIndex = [[[self view] subviews] count] - 1;
    [[self view] insertSubview:canvasView_ atIndex:viewIndex];
}


#pragma mark -
#pragma mark Touch Event Handlers

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    startPoint_ = [[touches anyObject] locationInView:canvasView_];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint lastPoint = [[touches anyObject] previousLocationInView:canvasView_];
  
    // add a new stroke to scribble if this is indeed a drag from a finger
    if (CGPointEqualToPoint(lastPoint, startPoint_) && !_isTouchDrawing)
    {
        _isTouchDrawing = YES;
        id <Mark> newStroke = [[Stroke alloc] init];// autorelease];//tyler
        [newStroke setColor:strokeColor_];
        [newStroke setSize:strokeSize_];
    
        //[scribble_ addMark:newStroke shouldAddToPreviousMark:NO];
    
        // retrieve a new NSInvocation for drawing and set new arguments for the draw command
        NSInvocation *drawInvocation = [self drawScribbleInvocation];
        [drawInvocation setArgument:&newStroke atIndex:2];
    
        // retrieve a new NSInvocation for undrawing and set a new argument for the undraw command
        NSInvocation *undrawInvocation = [self undrawScribbleInvocation];
        [undrawInvocation setArgument:&newStroke atIndex:2];
    
        // execute the draw command with the undraw command
        [self executeInvocation:drawInvocation withUndoInvocation:undrawInvocation];
    }
  
    // add the current touch as another vertex to the temp stroke
    CGPoint thisPoint = [[touches anyObject] locationInView:canvasView_];
    Vertex *vertex = [[Vertex alloc] initWithLocation:thisPoint];// autorelease]; //tyler
  
    // we don't need to undo every vertex so we are keeping this
    [scribble_ addMark:vertex shouldAddToPreviousMark:YES];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    CGPoint lastPoint = [[touches anyObject] previousLocationInView:canvasView_];
    CGPoint thisPoint = [[touches anyObject] locationInView:canvasView_];
  
    // if the touch never moves (stays at the same spot until lifted now)
    // just add a dot to an existing stroke composite
    // otherwise add it to the temp stroke as the last vertex
    if (CGPointEqualToPoint(startPoint_, thisPoint) && _isTouchDrawing) //CGPointEqualToPoint(lastPoint, thisPoint)
    {
        _isTouchDrawing = NO;
        Dot *singleDot = [[Dot alloc]
                          initWithLocation:thisPoint];//autorelease]; //tyler
        [singleDot setColor:strokeColor_];
        [singleDot setSize:strokeSize_];

        //[scribble_ addMark:singleDot shouldAddToPreviousMark:NO];

        // retrieve a new NSInvocation for drawing and
        // set new arguments for the draw command
        NSInvocation *drawInvocation = [self drawScribbleInvocation];
        [drawInvocation setArgument:&singleDot atIndex:2];

        // retrieve a new NSInvocation for undrawing and set a new argument for the undraw command
        NSInvocation *undrawInvocation = [self undrawScribbleInvocation];
        [undrawInvocation setArgument:&singleDot atIndex:2];

        // execute the draw command with the undraw command
        [self executeInvocation:drawInvocation withUndoInvocation:undrawInvocation];
    }
   
    // reset the start point here
    startPoint_ = CGPointZero;
    _isTouchDrawing = NO;
  
    // if this is the last point of stroke don't bother to draw it as the user won't tell the difference
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    
    // reset the start point here
    startPoint_ = CGPointZero;
    _isTouchDrawing = NO;
}


#pragma mark -
#pragma mark Scribble observer method
- (void) observeValueForKeyPath:(NSString *)keyPath 
                       ofObject:(id)object 
                         change:(NSDictionary *)change 
                        context:(void *)context
{
  if ([object isKindOfClass:[Scribble class]] && 
      [keyPath isEqualToString:@"mark"])
  {
    id <Mark> mark = [change objectForKey:NSKeyValueChangeNewKey];
    [canvasView_ setMark:mark];
    [canvasView_ setNeedsDisplay];
  }
}


#pragma mark -
#pragma mark Draw Scribble Invocation Generation Methods

- (NSInvocation *) drawScribbleInvocation {
    
    NSMethodSignature *executeMethodSignature = [scribble_
                                               methodSignatureForSelector:
                                               @selector(addMark:
                                                         shouldAddToPreviousMark:)];
    NSInvocation *drawInvocation = [NSInvocation
                                  invocationWithMethodSignature:
                                  executeMethodSignature];
    [drawInvocation setTarget:scribble_];
    [drawInvocation setSelector:@selector(addMark:shouldAddToPreviousMark:)];
    BOOL attachToPreviousMark = NO;
    [drawInvocation setArgument:&attachToPreviousMark atIndex:3];
  
    return drawInvocation;
}

- (NSInvocation *) undrawScribbleInvocation {
    
    NSMethodSignature *unexecuteMethodSignature = [scribble_
                                                 methodSignatureForSelector:
                                                 @selector(removeMark:)];
    NSInvocation *undrawInvocation = [NSInvocation
                                    invocationWithMethodSignature:
                                    unexecuteMethodSignature];
    [undrawInvocation setTarget:scribble_];
    [undrawInvocation setSelector:@selector(removeMark:)];
    
    return undrawInvocation;
}

#pragma mark Draw Scribble Command Methods
//命令模式-实现: 撤销操作、恢复操作;
- (void) executeInvocation:(NSInvocation *)invocation 
        withUndoInvocation:(NSInvocation *)undoInvocation {
    
    //保留参数 和 返回值
    [invocation retainArguments];

    //注册操作
    [[self.undoManager prepareWithInvocationTarget:self] unexecuteInvocation:undoInvocation withRedoInvocation:invocation];
  
    [invocation invoke];
}

- (void) unexecuteInvocation:(NSInvocation *)invocation 
          withRedoInvocation:(NSInvocation *)redoInvocation
{  
  [[self.undoManager prepareWithInvocationTarget:self] executeInvocation:redoInvocation withUndoInvocation:invocation];
  
  [invocation invoke];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}
/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */
@end
