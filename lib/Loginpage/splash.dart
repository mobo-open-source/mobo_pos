import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The application splash screen, which plays a branding video before navigating to the main flow.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    
    
    // Set full screen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    _initializeVideo();
  }

  /// Initializes the video player and begins playback.
  Future<void> _initializeVideo() async {
    try {
      
      // Initialize video controller with the MP4 asset
      _videoController = VideoPlayerController.asset('assets/pos.mp4');
      
      
      // Initialize video
      await _videoController!.initialize();
      
      
      if (mounted) {
        
        // Update state first to show video
        setState(() {
          _isVideoInitialized = true;
        });
        
        // Small delay to ensure UI is updated, then start playing
        await Future.delayed(Duration(milliseconds: 100));
        
        // Start playing
        await _videoController!.play();
        
        // Listen for video completion
        _videoController!.addListener(_videoListener);
        
        // Add a fallback timer - use fixed 5 seconds if duration is not available
        final videoDuration = _videoController!.value.duration;
        final fallbackDuration = videoDuration.inMilliseconds > 0 
            ? videoDuration + const Duration(seconds: 1)
            : const Duration(seconds: 5);
        
        
        Timer(fallbackDuration, () {
          if (mounted) {
            _navigateToNextScreen();
          }
        });
      } else {
      }
    } catch (e) {
      _handleVideoError('Video initialization failed: $e');
    }
  }
  
  void _handleVideoError(String error) {
    if (mounted) {
      // Show fallback splash for 3 seconds then navigate
      setState(() {
        _isVideoInitialized = false;
      });
      
      // Navigate after showing fallback splash
      Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _navigateToNextScreen();
        }
      });
    }
  }

  void _videoListener() {
    if (_videoController != null && 
        _videoController!.value.position >= _videoController!.value.duration) {
      // Video finished, navigate to next screen
      _navigateToNextScreen();
    }
  }

  /// Navigates to the appropriate screen (Get Started or Init) after video completion or error.
  void _navigateToNextScreen() async {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    if (mounted) {
      // Check if user has seen the get started screen
      final prefs = await SharedPreferences.getInstance();
      final hasSeenGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;
      
      if (!hasSeenGetStarted) {
        Navigator.pushReplacementNamed(context, '/get_started');
      } else {
        Navigator.pushReplacementNamed(context, '/init');
      }
    } else {
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    
    // Restore system UI in case it wasn't restored
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoController != null) {
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFC03355), // Use POS primary color
      body: Stack(
        children: [
          // Always show the video if initialized
          if (_isVideoInitialized && _videoController != null && _videoController!.value.isInitialized)
            Container(
              width: double.infinity,
              height: double.infinity,
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
          
          // Fallback splash when video is not available - just background color
          if (!_isVideoInitialized || _videoController == null || !_videoController!.value.isInitialized)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color(0xFFC03355), // POS primary color background
            ),
        ],
      ),
    );
  }
}
