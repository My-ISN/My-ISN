import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

class ProjectTaskService {
  static const String baseUrl = AppConstants.baseUrl;
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> getProjects({int? limit, int? page, String? search, int? departmentId}) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      String urlStr = '$baseUrl/get_projects?user_id=$userId';
      if (limit != null) urlStr += '&limit=$limit';
      if (page != null) urlStr += '&page=$page';
      if (search != null && search.isNotEmpty) urlStr += '&search=${Uri.encodeComponent(search)}';
      if (departmentId != null) urlStr += '&department_id=$departmentId';

      final url = Uri.parse(urlStr);
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getProjectStats({String? search, int? departmentId}) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      String urlStr = '$baseUrl/get_project_stats?user_id=$userId';
      if (search != null && search.isNotEmpty) urlStr += '&search=${Uri.encodeComponent(search)}';
      if (departmentId != null) urlStr += '&department_id=$departmentId';

      final url = Uri.parse(urlStr);
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getProjectDetails(int projectId) async {
    return _getRequest('/get_project_details', {'project_id': projectId.toString()});
  }

  Future<Map<String, dynamic>> updateProjectDetails(Map<String, dynamic> data) async {
    return _postRequest('/update_project_details', data);
  }

  Future<Map<String, dynamic>> getTasks({int? projectId, int? limit, int? page, String? search, int? departmentId}) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      String urlStr = '$baseUrl/get_tasks?user_id=$userId';
      if (projectId != null) urlStr += '&project_id=$projectId';
      if (limit != null) urlStr += '&limit=$limit';
      if (page != null) urlStr += '&page=$page';
      if (search != null && search.isNotEmpty) urlStr += '&search=${Uri.encodeComponent(search)}';
      if (departmentId != null) urlStr += '&department_id=$departmentId';

      final url = Uri.parse(urlStr);
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getTaskDetails(int taskId) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      final url = Uri.parse('$baseUrl/get_task_details?user_id=$userId&task_id=$taskId');
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addTask(Map<String, dynamic> data) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      final url = Uri.parse('$baseUrl/add_task');
      final response = await http.post(url, body: {
        ...data.map((key, value) => MapEntry(key, value.toString())),
        'user_id': userId.toString(),
      });
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateTaskStatus(int taskId, {int? status, int? progress}) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      final Map<String, String> body = {
        'user_id': userId.toString(),
        'task_id': taskId.toString(),
      };
      if (status != null) body['status'] = status.toString();
      if (progress != null) body['progress'] = progress.toString();

      final url = Uri.parse('$baseUrl/update_task_status');
      final response = await http.post(url, body: body);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

    Future<Map<String, dynamic>> getAllProjects() async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      final url = Uri.parse('$baseUrl/get_all_projects?user_id=$userId');
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getEmployees() async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final companyId = userData['company_id'] ?? 2;

      final url = Uri.parse('$baseUrl/get_employees?company_id=$companyId&limit=100');
      final response = await http.get(url);
      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getDepartments() async {
    return _getRequest('/get_departments', {});
  }

  Future<Map<String, dynamic>> getClients() async {
    return _getRequest('/get_clients', {});
  }

  // ==========================================
  // NEW TABS API
  // ==========================================

  Future<Map<String, dynamic>> updateTaskDetails(Map<String, dynamic> data) async {
    return _postRequest('/update_task_details', data);
  }

  Future<Map<String, dynamic>> getTaskDiscussions(int taskId) async {
    return _getRequest('/get_task_discussions', {'task_id': taskId.toString()});
  }

  Future<Map<String, dynamic>> addTaskDiscussion(int taskId, String description) async {
    return _postRequest('/add_task_discussion', {
      'task_id': taskId.toString(),
      'description': description,
    });
  }

  Future<Map<String, dynamic>> deleteTaskDiscussion(int discussionId) async {
    return _postRequest('/delete_task_discussion', {
      'discussion_id': discussionId.toString(),
    });
  }

  Future<Map<String, dynamic>> getTaskNotes(int taskId) async {
    return _getRequest('/get_task_notes', {'task_id': taskId.toString()});
  }

  Future<Map<String, dynamic>> addTaskNote(int taskId, String description) async {
    return _postRequest('/add_task_note', {
      'task_id': taskId.toString(),
      'description': description,
    });
  }

  Future<Map<String, dynamic>> deleteTaskNote(int noteId) async {
    return _postRequest('/delete_task_note', {
      'note_id': noteId.toString(),
    });
  }

  Future<Map<String, dynamic>> getTaskFiles(int taskId) async {
    return _getRequest('/get_task_files', {'task_id': taskId.toString()});
  }

  Future<Map<String, dynamic>> uploadTaskFile(int taskId, String fileName, String filePath) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      final url = Uri.parse('$baseUrl/upload_task_file');
      var request = http.MultipartRequest('POST', url);
      request.fields['user_id'] = userId.toString();
      request.fields['task_id'] = taskId.toString();
      request.fields['file_name'] = fileName;

      request.files.add(await http.MultipartFile.fromPath('attachment_file', filePath));
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        return {'status': false, 'message': 'Server error: ${response.statusCode}'};
      }
      
      try {
        return json.decode(responseData);
      } catch (e) {
        return {'status': false, 'message': 'Invalid response from server (Not JSON)'};
      }
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteTaskFile(int fileId) async {
    return _postRequest('/delete_task_file', {
      'file_id': fileId.toString(),
    });
  }

  Future<Map<String, dynamic>> getProjectTodos(int taskId) async {
    return _getRequest('/get_project_todos', {'task_id': taskId.toString()});
  }

  Future<Map<String, dynamic>> addProjectTodo(int taskId, String todoText) async {
    return _postRequest('/add_project_todo', {
      'task_id': taskId.toString(),
      'todo_text': todoText,
    });
  }

  Future<Map<String, dynamic>> editProjectTodo(int todoId, String todoText) async {
    return _postRequest('/edit_project_todo', {
      'todo_id': todoId.toString(),
      'todo_text': todoText,
    });
  }

  Future<Map<String, dynamic>> toggleProjectTodo(int todoId) async {
    return _postRequest('/toggle_project_todo', {
      'todo_id': todoId.toString(),
    });
  }

  Future<Map<String, dynamic>> deleteProjectTodo(int todoId) async {
    return _postRequest('/delete_project_todo', {
      'todo_id': todoId.toString(),
    });
  }

  Future<Map<String, dynamic>> addProject(Map<String, dynamic> data) async {
    return _postRequest('/add_project', data);
  }

  Future<Map<String, dynamic>> deleteTask(int taskId) async {
    return _postRequest('/delete_task', {'task_id': taskId.toString()});
  }

  Future<Map<String, dynamic>> deleteProject(int projectId) async {
    return _postRequest('/delete_project', {'project_id': projectId.toString()});
  }

  // ==========================================
  // UTILS
  // ==========================================


  Future<Map<String, dynamic>> _getRequest(String endpoint, [Map<String, String>? queryParams]) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      queryParams ??= {};
      queryParams['user_id'] = userId.toString();
      final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
      final response = await http.get(uri);
      
      if (response.statusCode != 200) {
        return {'status': false, 'message': 'Server error: ${response.statusCode}'};
      }
      
      try {
        return json.decode(response.body);
      } catch (e) {
        return {'status': false, 'message': 'Invalid response from server (Not JSON)'};
      }
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _postRequest(String endpoint, Map<String, dynamic> body) async {
    try {
      String? userDataString = await _storage.read(key: 'user_data');
      if (userDataString == null) return {'status': false, 'message': 'User not logged in'};
      final userData = json.decode(userDataString);
      final userId = userData['id'] ?? userData['user_id'];

      body['user_id'] = userId.toString();
      // Ensure all values are strings for http.post body
      final Map<String, String> stringBody = body.map((key, value) => MapEntry(key, value.toString()));

      final url = Uri.parse('$baseUrl$endpoint');
      final response = await http.post(url, body: stringBody);
      
      if (response.statusCode != 200) {
        return {'status': false, 'message': 'Server error: ${response.statusCode}'};
      }

      try {
        return json.decode(response.body);
      } catch (e) {
        return {'status': false, 'message': 'Invalid response from server (Not JSON)'};
      }
    } catch (e) {
      return {'status': false, 'message': e.toString()};
    }
  }
}
