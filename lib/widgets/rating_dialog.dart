import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../services/review_service.dart';
import '../core/style.dart';

class CustomRatingDialog extends StatefulWidget {
  final Function(double, String) onGoodReview;
  final Function(double, String) onBadReview;

  const CustomRatingDialog({
    Key? key,
    required this.onGoodReview,
    required this.onBadReview,
  }) : super(key: key);

  @override
  _CustomRatingDialogState createState() => _CustomRatingDialogState();

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CustomRatingDialog(
        onGoodReview: (rating, comment) {
          Navigator.pop(context);
          ReviewService().forceRequestReview();
        },
        onBadReview: (rating, comment) {
          Navigator.pop(context);
          ReviewService().sendEmailFeedback(rating, comment);
        },
      ),
    );
  }
}

class _CustomRatingDialogState extends State<CustomRatingDialog> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppStyle.primaryColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.stars_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                children: [
                  Text(
                    'Rate Us',
                    style: AppStyle.font(
                      weight: FontWeight.bold,
                      size: 22,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell others what you think about this app',
                    textAlign: TextAlign.center,
                    style: AppStyle.font(
                      weight: FontWeight.w600,
                      size: 14,
                      color: primaryColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Rating Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        RatingBar.builder(
                          initialRating: 5,
                          minRating: 1,
                          direction: Axis.horizontal,
                          allowHalfRating: false,
                          itemCount: 5,
                          itemPadding: const EdgeInsets.symmetric(horizontal: 2.0),
                          unratedColor: Colors.grey[300],
                          itemSize: 34,
                          itemBuilder: (context, _) => const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                          ),
                          onRatingUpdate: (rating) {
                            setState(() {
                              _rating = rating;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Submit/Continue Button inside the box
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_rating >= 4) {
                                widget.onGoodReview(_rating, _commentController.text);
                              } else {
                                widget.onBadReview(_rating, _commentController.text);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 1,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${_rating.toInt()}/5  ',
                                  style: AppStyle.font(
                                    weight: FontWeight.bold,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'CONTINUE',
                                  style: AppStyle.font(
                                    weight: FontWeight.bold,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Comment Box (Only show for ratings < 4 stars)
                  Visibility(
                    visible: _rating < 4,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _commentController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Any comments or feedback? (Optional)',
                          hintStyle: AppStyle.font(size: 12, color: Colors.grey),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.black12 : Colors.grey[50],
                        ),
                        style: AppStyle.font(
                          size: 12,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () async {
                      await ReviewService().neverAskAgain();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'NEVER ASK AGAIN',
                      style: AppStyle.font(
                        weight: FontWeight.bold,
                        size: 11,
                        color: primaryColor.withOpacity(0.6),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'ASK ME LATER',
                      style: AppStyle.font(
                        weight: FontWeight.bold,
                        size: 11,
                        color: primaryColor.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
