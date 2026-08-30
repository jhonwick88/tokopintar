import sys

# 1. Update main.dart
main_path = r'H:\FlutterProject\tokopintar\lib\main.dart'
with open(main_path, 'r', encoding='utf-8') as f:
    main_content = f.read()

if 'flutter_dotenv' not in main_content:
    main_content = main_content.replace(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';", 
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:flutter_dotenv/flutter_dotenv.dart';"
    )
    main_content = main_content.replace(
        "void main() async {", 
        "void main() async {\n  await dotenv.load(fileName: \".env\");"
    )
    with open(main_path, 'w', encoding='utf-8') as f:
        f.write(main_content)

# 2. Update settings_model.dart
model_path = r'H:\FlutterProject\tokopintar\lib\data\models\settings_model.dart'
with open(model_path, 'r', encoding='utf-8') as f:
    model_content = f.read()

if 'flutter_dotenv' not in model_content:
    model_content = "import 'package:flutter_dotenv/flutter_dotenv.dart';\n" + model_content
    model_content = model_content.replace(
        "this.restApiUrl = 'http://localhost:8181',", 
        "this.restApiUrl = '',"
    )
    model_content = model_content.replace(
        "this.restApiUrl = '',", 
        "// this.restApiUrl will be initialized in the constructor body if empty\n    this.restApiUrl = '',"
    )
    
    # Let's do it safer:
    model_content = model_content.replace(
        "restApiUrl: json['rest_api_url'] as String? ?? 'http://localhost:8181',",
        "restApiUrl: json['rest_api_url'] as String? ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:8181',"
    )
    with open(model_path, 'w', encoding='utf-8') as f:
        f.write(model_content)

# 3. Update settings_repository_impl.dart
repo_path = r'H:\FlutterProject\tokopintar\lib\data\repositories\settings_repository_impl.dart'
with open(repo_path, 'r', encoding='utf-8') as f:
    repo_content = f.read()

if 'flutter_dotenv' not in repo_content:
    repo_content = "import 'package:flutter_dotenv/flutter_dotenv.dart';\n" + repo_content
    repo_content = repo_content.replace(
        "final localUrl = prefs.getString('local_rest_api_url') ?? 'http://localhost:8181';",
        "final localUrl = prefs.getString('local_rest_api_url') ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:8181';"
    )
    with open(repo_path, 'w', encoding='utf-8') as f:
        f.write(repo_content)
