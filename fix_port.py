import os

files = [
    r'H:\FlutterProject\tokopintar\lib\data\models\settings_model.dart',
    r'H:\FlutterProject\tokopintar\lib\data\repositories\settings_repository_impl.dart',
    r'H:\FlutterProject\tokopintar\lib\presentation\screens\login_screen.dart',
    r'H:\FlutterProject\tokopintar\lib\presentation\screens\settings_screen.dart'
]

for path in files:
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # We only want to replace local urls
        content = content.replace('http://localhost:8080', 'http://localhost:8181')
        content = content.replace('http://192.168.x.x:8080', 'http://192.168.x.x:8181')
        
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
