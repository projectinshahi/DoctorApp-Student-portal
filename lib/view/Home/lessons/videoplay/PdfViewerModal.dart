import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../widget/app_shimmer.dart';

/// Bottom-sheet PDF viewer, used for lesson notes. Renamed from the
/// original private `_PdfViewerModal` to a public class so it can be
/// imported and used from `student_lesson_detail_screen.dart`.
class PdfViewerModal extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerModal({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<PdfViewerModal> createState() => _PdfViewerModalState();
}

class _PdfViewerModalState extends State<PdfViewerModal> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                SfPdfViewer.network(
                  widget.pdfUrl,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                  onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                    setState(() => _isLoading = false);
                  },
                  onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                    setState(() {
                      _isLoading = false;
                      _hasError = true;
                    });
                  },
                ),
                // The page is a known-size sheet, so it greys out while the
                // document loads instead of showing a spinner over blank.
                if (_isLoading)
                  const Positioned.fill(
                    child: AppShimmer(
                      child: ShimmerBox(width: double.infinity, height: double.infinity, radius: 0),
                    ),
                  ),
                if (_hasError)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 36.sp),
                        SizedBox(height: 8.h),
                        Text('Failed to load PDF document.', style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}