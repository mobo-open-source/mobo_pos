import 'dart:async';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GetStartedScreen extends StatefulWidget {
  final bool useStandardFonts;
  const GetStartedScreen({super.key, this.useStandardFonts = false});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  final List<Map<String, String>> carouselData = [
    {
      'image': 'assets/CRM1.jpg',
      'title': 'Streamline Your Sales',
      'subtitle': 'Manage your point of sale operations efficiently with Odoo POS',
    },
    {
      'image': 'assets/CRM2.jpg',
      'title': 'Real-Time Inventory',
      'subtitle': 'Track your inventory in real-time and never run out of stock',
    },
    {
      'image': 'assets/CRM3.jpg',
      'title': 'Customer Management',
      'subtitle': 'Build lasting relationships with comprehensive customer data',
    },
  ];

  int currentIndex = 0;
  late PageController _pageController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (currentIndex < carouselData.length - 1) {
        currentIndex++;
      } else {
        currentIndex = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          currentIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _markGetStartedSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenGetStarted', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Stack(
        children: [
          // Full background carousel images
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              itemCount: carouselData.length,
              itemBuilder: (context, index) {
                final data = carouselData[index];
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC03355),

                    image: DecorationImage(
                      image: AssetImage(data['image']!),
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                  // Add a dark overlay for better text readability
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Overlay content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = constraints.maxWidth > constraints.maxHeight;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 60 : 40,
                    vertical: isLandscape ? 20 : 40,
                  ),
                  child: Column(
                    children: [
                      // Top section with logo
                      // Row(
                      //   children: [
                      //     Container(
                      //       padding: const EdgeInsets.all(8),
                      //       decoration: BoxDecoration(
                      //         color: const Color(0xFFC03355).withOpacity(0.9),
                      //         borderRadius: BorderRadius.circular(12),
                      //       ),
                      //       child: Icon(
                      //         Icons.point_of_sale,
                      //         color: Colors.white,
                      //         size: isLandscape ? 24 : 28,
                      //       ),
                      //     ),
                      //     const SizedBox(width: 12),
                      //     Text(
                      //       'Odoo Community POS',
                      //       style: GoogleFonts.manrope(
                      //         fontSize: isLandscape ? 18 : 20,
                      //         fontWeight: FontWeight.bold,
                      //         color: Colors.white,
                      //         shadows: const [
                      //           Shadow(
                      //             offset: Offset(0, 2),
                      //             blurRadius: 4,
                      //             color: Colors.black54,
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   ],
                      // ),

                      // Spacer to push content to bottom
                      const Spacer(),

                      // Bottom section with text, button and dots
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Dynamic text content based on current slide
                          Text(
                            carouselData[currentIndex]['title']!,
                            textAlign: TextAlign.center,
                            style: widget.useStandardFonts
                                ? TextStyle(
                                    fontSize: isLandscape ? 24 : 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        offset: Offset(0, 2),
                                        blurRadius: 4,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  )
                                : GoogleFonts.manrope(
                                    fontSize: isLandscape ? 24 : 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        offset: Offset(0, 2),
                                        blurRadius: 4,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                          ),
                          SizedBox(height: isLandscape ? 10 : 15),
                          Text(
                            carouselData[currentIndex]['subtitle']!,
                            textAlign: TextAlign.center,
                            style: widget.useStandardFonts
                                ? TextStyle(
                                    fontSize: isLandscape ? 14 : 16,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 2,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  )
                                : GoogleFonts.manrope(
                                    fontSize: isLandscape ? 14 : 16,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        offset: Offset(0, 1),
                                        blurRadius: 2,
                                        color: Colors.black54,
                                      ),
                                    ],
                                  ),
                          ),

                          SizedBox(height: isLandscape ? 30 : 40),

                          // Get Started button
                          SizedBox(
                            height: isLandscape ? 45 : 55,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                await _markGetStartedSeen();
                                if (context.mounted) {
                                  Navigator.pushReplacementNamed(context, '/init');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC03355),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: Colors.black.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                "Get Started",
                                style: widget.useStandardFonts
                                    ? TextStyle(
                                        fontSize: isLandscape ? 16 : 18,
                                        fontWeight: FontWeight.w600,
                                      )
                                    : GoogleFonts.manrope(
                                        fontSize: isLandscape ? 16 : 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                              ),
                            ),
                          ),

                          SizedBox(height: isLandscape ? 15 : 20),

                          // Dots indicator at the bottom
                          DotsIndicator(
                            dotsCount: carouselData.length,
                            position: currentIndex.toDouble(),
                            decorator: DotsDecorator(
                              activeColor: const Color(0xFFC03355),
                              color: Colors.white.withOpacity(0.4),
                              size: Size.square(isLandscape ? 6.0 : 8.0),
                              activeSize: Size(isLandscape ? 12.0 : 16.0, isLandscape ? 6.0 : 8.0),
                              activeShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                            ),
                          ),

                          SizedBox(height: isLandscape ? 10 : 20),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
