import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';
import '../models/course_details_model.dart';

class CourseDetailsService {
  static const String _baseUrl = 'http://localhost:3000/api';

  Future<CourseDetails?> fetchCourseDetails(int courseId) async {
    final String? token = await AdminLocalStorage.getToken();

    final Uri url = Uri.parse('$_baseUrl/courses/$courseId');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonBody = json.decode(response.body);
      final courseResponse = CourseDetailsResponse.fromJson(jsonBody);
      return courseResponse.course;
    } else {
      throw Exception(
        'Failed to load course details. Status Code: ${response.statusCode}',
      );
    }
  }
}