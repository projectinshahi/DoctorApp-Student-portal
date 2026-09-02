// lib/view/Home/profile/plans_screen.dart
import 'package:flutter/material.dart';

import '../../../widget/app_snackbar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../View_model/plan_model.dart';
import '../../../core/theam /app_color.dart';
import '../../../repository/plan_provider.dart';
import '../../../repository/profile_provider.dart';
import '../../../repository/selection_content_provider.dart';
import '../../../widget/app_shimmer.dart';

class PlansScreen extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const PlansScreen({super.key, required this.courseId, required this.courseTitle});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanProvider>().loadPlans(widget.courseId);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubscribe(PlanProvider planProvider, int planId) async {
    final success = await planProvider.subscribe(planId);
    if (!mounted) return;

    if (!success) {
      showAppSnackBar(
        context,
        planProvider.subscribeErrorMessage ?? 'Failed to subscribe',
        kind: AppMessage.failure,
      );
      return;
    }

    // Refresh both so the profile badge and the lesson lock icons update.
    await Future.wait([
      context.read<ProfileProvider>().loadProfile(),
      context.read<SelectionContentProvider>().loadContent(),
    ]);
    if (!mounted) return;

    showAppSnackBar(context, 'Subscribed successfully!');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.Screenbackground,
      appBar: AppBar(
        backgroundColor: AppColor.Screenbackground,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.sp, color: AppColor.Textcolor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Choose your plan',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700, color: AppColor.Textcolor),
        ),
      ),
      body: Consumer<PlanProvider>(
        builder: (context, planProvider, _) {
          if (planProvider.isLoadingPlans) {
            return const ScreenShimmer(layout: ShimmerLayout.cards);
          }
          if (planProvider.plansErrorMessage != null && planProvider.plans.isEmpty) {
            return Center(child: Text(planProvider.plansErrorMessage!));
          }
          if (planProvider.plans.isEmpty) {
            return const Center(child: Text('No plans available for this course yet.'));
          }

          final plans = planProvider.plans;
          final selected = plans[_currentPage.clamp(0, plans.length - 1)];

          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: plans.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  // Scrollable so the card hugs its content and still copes
                  // with a long feature list.
                  itemBuilder: (context, index) => SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
                    child: _PlanCard(plan: plans[index]),
                  ),
                ),
              ),
              if (plans.length > 1) ...[
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(plans.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.symmetric(horizontal: 3.w),
                      height: 6.h,
                      width: active ? 20.w : 6.w,
                      decoration: BoxDecoration(
                        color: active ? AppColor.buttoncolor : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    );
                  }),
                ),
              ],
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: ElevatedButton(
                        onPressed: planProvider.isSubscribing
                            ? null
                            : () => _handleSubscribe(planProvider, selected.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColor.buttoncolor,
                          foregroundColor: AppColor.Buttontextcolor,
                          disabledBackgroundColor: AppColor.buttoncolor.withOpacity(0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        child: planProvider.isSubscribing
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'Subscribe',
                                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColor.Textcolor,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        child: Text(
                          'Cancel Anytime',
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanModel plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColor.buttoncolor, AppColor.buttoncolor.withOpacity(0.25), const Color(0xFF7BB8F5)],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23.r)),
        padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 18.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AED ${plan.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 34.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColor.Textcolor,
                    height: 1.1,
                  ),
                ),
                SizedBox(width: 4.w),
                Padding(
                  padding: EdgeInsets.only(top: 14.h),
                  child: Text(
                    '/${plan.periodLabel}',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColor.buttoncolor,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(Icons.workspace_premium_rounded, size: 22.sp, color: Colors.white),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              plan.title,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: AppColor.buttoncolor),
            ),
            if (plan.description != null && plan.description!.trim().isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                plan.description!.trim(),
                style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade600, height: 1.4),
              ),
            ],
            if (plan.features.isNotEmpty) ...[
              SizedBox(height: 18.h),
              Text(
                'What you get',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: AppColor.Textcolor),
              ),
              SizedBox(height: 10.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppColor.Screenbackground.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    for (final feature in plan.features)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 5.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16.sp, color: AppColor.buttoncolor),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                feature,
                                style: TextStyle(fontSize: 12.5.sp, color: AppColor.Textcolor, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}
