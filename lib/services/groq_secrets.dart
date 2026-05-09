import 'package:flutter_dotenv/flutter_dotenv.dart';

String get kGroqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';
