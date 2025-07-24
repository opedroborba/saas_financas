import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:saas_shinko/screens/auth_screen.dart';
import 'package:saas_shinko/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Substitua com a sua URL e Anon Key do Supabase
  await Supabase.initialize(
    url:
        'https://hqlvkxckmprqldqrxchh.supabase.co', // Ex: 'https://xyzabcdefghi.supabase.co'
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhxbHZreGNrbXBycWxkcXJ4Y2hoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE5ODEwMDAsImV4cCI6MjA2NzU1NzAwMH0.PWE3bTZIrgVe8nRWS9CWrjGn7A1idzAkgAqCIPwOWnc', // Ex: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // Definindo as cores globais para o tema
  static const Color primaryOrange = Color(0xFFF7A102); // Este é o seu âmbar
  static const Color secondaryDarkBlue = Color(0xFF1A237E);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color dangerRed = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shinkō Finanças',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Remova ou ajuste primarySwatch se não for necessário para cores secundárias
        // primarySwatch: Colors.blue, // Pode ser removido ou alterado para uma cor mais próxima do laranja se quiser variações de laranja

        primaryColor:
            primaryOrange, // <--- MUDANÇA AQUI: Define a cor primária global como âmbar
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary:
              primaryOrange, // <--- MUDANÇA AQUI: Define a cor primária do ColorScheme como âmbar
          secondary:
              secondaryDarkBlue, // A cor secundária pode ser o azul escuro
          error: dangerRed,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor:
              primaryOrange, // <--- MUDANÇA AQUI: A cor de fundo da AppBar será âmbar
          foregroundColor: Colors.white, // Cor do texto e ícones na AppBar
          elevation: 4,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryOrange, // Cor do FAB
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white, // Cor do texto do botão
            backgroundColor: primaryOrange, // Cor de fundo do botão
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: secondaryDarkBlue),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primaryOrange, width: 2),
          ),
          labelStyle: const TextStyle(color: secondaryDarkBlue),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: Supabase.instance.client.auth.currentUser == null
          ? const AuthScreen()
          : const HomeScreen(),
    );
  }
}
