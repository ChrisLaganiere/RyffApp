//
//  RYRefreshControl.m
//  Ryff
//
//  Created by Christopher Laganiere on 9/7/14.
//  Copyright (c) 2014 Chris Laganiere. All rights reserved.
//

#import "RYRefreshControl.h"

#define kRefreshPullHeight 60.0f
#define kRefreshControlHeight 60.0f
#define kRefreshControlWidth 200.0f

@interface RYRefreshControl ()

@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) CAShapeLayer *circleShape;

// Data
@property (nonatomic, assign) UIEdgeInsets originalContentInset;
@property (nonatomic, assign) BOOL canRefresh;
@property (nonatomic, assign) BOOL ignoreEdges;

@end

@implementation RYRefreshControl

#pragma mark -
#pragma mark - Life Cycle

- (id) initInScrollView:(UIScrollView *)scrollView
{
    if (self = [super initWithFrame:CGRectMake(0.5*(scrollView.frame.size.width-kRefreshControlWidth), -(kRefreshControlHeight + scrollView.contentInset.top), kRefreshControlWidth, kRefreshControlHeight)])
    {
        _scrollView             = scrollView;
        _originalContentInset   = scrollView.contentInset;
        
        _tintColor = [UIColor whiteColor];
        
        self.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;
        [scrollView addSubview:self];
        [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
        [scrollView addObserver:self forKeyPath:@"contentInset" options:NSKeyValueObservingOptionNew context:nil];
        
        _activityIndicator                  = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _activityIndicator.center           = CGPointMake(floor(self.frame.size.width / 2), floor(self.frame.size.height / 2));
        _activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _activityIndicator.hidesWhenStopped = YES;
        [_activityIndicator stopAnimating];
        [self addSubview:_activityIndicator];
        
        CGRect circleFrame          = CGRectMake(0.5f*(self.frame.size.width-50.0f), 0.5f*(self.frame.size.height-50.0f), 50.0f, 50.0f);
        CGPoint circleCenter        = CGPointMake(circleFrame.size.width/2, circleFrame.size.height/2);
        CGFloat outerStrokeWidth    = 4.0f;
        _circleShape                = [CAShapeLayer layer];
        _circleShape.path           = [UIBezierPath bezierPathWithArcCenter:circleCenter radius:(circleFrame.size.width-outerStrokeWidth/2) / 2 startAngle:-M_PI_2 endAngle:-M_PI_2 + 2 * M_PI clockwise:YES].CGPath;
        _circleShape.strokeColor    = _tintColor.CGColor;
        _circleShape.fillColor      = nil;
        _circleShape.lineWidth      = outerStrokeWidth;
        _circleShape.strokeEnd      = 0.75f;
        _circleShape.position       = circleFrame.origin;
        [self.layer addSublayer:_circleShape];
    }
    return self;
}

- (void)dealloc
{
    [_scrollView removeObserver:self forKeyPath:@"contentOffset"];
    [_scrollView removeObserver:self forKeyPath:@"contentInset"];
    _scrollView = nil;
}

- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    if (!newSuperview) {
        [_scrollView removeObserver:self forKeyPath:@"contentOffset"];
        [_scrollView removeObserver:self forKeyPath:@"contentInset"];
        _scrollView = nil;
    }
}

#pragma mark -
#pragma mark - Members

- (void) setTintColor:(UIColor *)tintColor
{
    _tintColor                      = tintColor;
    _activityIndicator.tintColor    = tintColor;
    _circleShape.strokeColor        = tintColor.CGColor;
}

#pragma mark -
#pragma mark - Shape Helpers

- (void) animateFill:(CAShapeLayer*)shapeLayer toStrokeEnd:(CGFloat)strokeEnd
{
    [shapeLayer removeAnimationForKey:@"strokeEnd"];
    
    CGFloat animationDuration = 0.1f;
    
    CABasicAnimation *fillStroke = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    fillStroke.duration          = animationDuration;
    fillStroke.fromValue         = @(shapeLayer.strokeEnd);
    fillStroke.toValue           = @(strokeEnd);
    shapeLayer.strokeEnd         = strokeEnd;
    [shapeLayer addAnimation:fillStroke forKey:@"fill stroke"];
}

#pragma mark -
#pragma mark - Actions

- (void) beginRefreshing
{
    
}

- (void) endRefreshing
{
    
}

#pragma mark - Internal

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"contentInset"])
    {
        if (!_ignoreEdges)
            _originalContentInset = [[change objectForKey:@"new"] UIEdgeInsetsValue];
    }
    else if ([keyPath isEqualToString:@"contentOffset"])
    {
        if (_ignoreEdges)
            return;
        
        CGFloat offset = [[change objectForKey:@"new"] CGPointValue].y + self.originalContentInset.top;
        
        if (_isRefreshing)
        {
            // already refreshing
            if (offset < 0.0f && offset >= -kRefreshControlHeight)
            {
                _ignoreEdges = YES;
                if (!self.scrollView.dragging)
                {
                    // was released above tipping point
                    UIEdgeInsets scrollViewInsets = _originalContentInset;
                    scrollViewInsets.top += kRefreshControlHeight;
                    [self.scrollView setContentInset:scrollViewInsets];
                }
                else
                {
                    // still touching
                    UIEdgeInsets scrollViewInsets = _originalContentInset;
                    scrollViewInsets.top -= offset;
                    [self.scrollView setContentInset:scrollViewInsets];
                }
                _ignoreEdges = NO;
            }
        }
        else
        {
            // not refreshing yet
            BOOL shouldDraw = YES;
            if (!_canRefresh)
            {
                if (offset >= 0.0f)
                {
                    // We can refresh again after the control is scrolled out of view
                    _canRefresh = YES;
                }
                else
                    shouldDraw = NO;
            }
            else
            {
                if (offset >= 0.0f)
                {
                    // Don't draw if the control is not visible
                    shouldDraw = NO;
                }
            }
            
            if (shouldDraw)
            {
                CGFloat percentPulled = MIN(-kRefreshControlHeight-offset,kRefreshPullHeight)/kRefreshPullHeight;
                if (percentPulled == 1.0f)
                {
                    _isRefreshing = YES;
                    _circleShape.hidden = YES;
                    [_activityIndicator startAnimating];
                    [self animateFill:_circleShape toStrokeEnd:0.0f];
                }
                else
                {
                    [self animateFill:_circleShape toStrokeEnd:percentPulled];
                }
                NSLog(@"offset: %02f",offset);
            }
        }
    }
}

@end