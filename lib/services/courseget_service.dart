import 'dart:convert';

import 'package:http/http.dart' as http;
import '../core/const/local_storegae.dart';
import '../models/course_get_model.dart';

class CourseListGetService {
  Future<List<CourseListGetModel>> fetchCourses({
    String? status,
    String? accessType,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final token = await AdminLocalStorage.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Admin not logged in. Please log in again.');
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    if (accessType != null && accessType.isNotEmpty) {
      queryParams['accessType'] = accessType;
    }

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final uri = Uri.parse('http://localhost:3000/api/courses')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final List<dynamic> list = data['courses'];

      return list
          .map((course) => CourseListGetModel.fromJson(course))
          .toList();
    } else {
      throw Exception(
        data['error']?['message'] ?? 'Failed to load courses',
      );
    }
  }
}