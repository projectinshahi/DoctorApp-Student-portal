import 'package:dr_app/core/constant/app_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../View_model/auth_result_model.dart';

class Homescreen extends StatefulWidget {
  final AuthResultModel authResult;
  const Homescreen({super.key, required this.authResult});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        color: AppColor.Screenbackground,
        child: Container(
          height: double.infinity,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Home screen")
            ],
          ),
        ),
      ),
    );
  }
}
