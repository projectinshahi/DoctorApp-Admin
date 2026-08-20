import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/const/local_storegae.dart';
import '../models/Course_model.dart';
import '../models/course_details_model.dart';
import '../core/const/api_constant.dart';

class CourseService {
  static const String _baseUrl = '${ApiConstant.baseUrl}/courses';

  Future<CourseModel> createCourse({
    required String title,
    required String status,
    String? description,
    String? thumbnail,
    String? classGrade,
    String? difficulty,
    String accessType = 'free',
    int displayOrder = 0,
    List<CourseTypeModel> courseTypes = const [],
  }) async {
    final token = await AdminLocalStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Admin not logged in. Please log in again.');
    }

    print('CourseService: Sending create course request...');

    late final http.Response response;

    final body = <String, dynamic>{
      'title': title,
      'description': description,
      'thumbnail': thumbnail,
      'classGrade': classGrade,
      'difficulty': difficulty,
      'accessType': accessType,
      'displayOrder': displayOrder,
      'status': status,
    };

    if (courseTypes.isNotEmpty) {
      body['courseTypes'] = courseTypes.map((ct) => ct.toJson()).toList();
    }

    try {
      response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    } catch (e, st) {
      print('CourseService: HTTP request THREW an error: $e');
      print('CourseService: Stack trace: $st');
      rethrow;
    }

    print('CourseService: Status code: ${response.statusCode}');
    print('CourseService: Response body: ${response.body}');

    if (response.statusCode == 201) {
      final result = CreateCourseResponse.fromJson(
        jsonDecode(response.body),
      );
      return result.course;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(
        error['error']?['message'] ?? 'Failed to create course',
      );
    }
  }




  // Add these two methods inside your existing CourseService class
// (keep your existing createCourse, getCourses, etc. as-is)

  Future<CourseDetails> updateCourse({
    required int courseId,
    String? title,
    String? description,
    String? thumbnail,
    String? classGrade,
    String? difficulty,
    String? accessType,
    int? displayOrder,
    String? status,
    List<String>? subjectNames,
  }) async {
    final String? token = await AdminLocalStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (thumbnail != null) body['thumbnail'] = thumbnail;
    if (classGrade != null) body['classGrade'] = classGrade;
    if (difficulty != null) body['difficulty'] = difficulty;
    if (accessType != null) body['accessType'] = accessType;
    if (displayOrder != null) body['displayOrder'] = displayOrder;
    if (status != null) body['status'] = status;
    if (subjectNames != null) body['subjectNames'] = subjectNames;

    final response = await http.put(
      Uri.parse('$_baseUrl/$courseId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return CourseDetails.fromJson(data['course']);
    } else {
      throw Exception(data['error']?['message'] ?? 'Failed to update course');
    }
  }

  Future<void> deleteCourse({required int courseId}) async {
    final String? token = await AdminLocalStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/$courseId'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error']?['message'] ?? 'Failed to delete course');
    }
  }

}