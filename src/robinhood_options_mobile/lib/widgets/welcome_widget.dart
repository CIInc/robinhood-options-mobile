import 'package:flutter/material.dart';

class WelcomeWidget extends StatelessWidget {
  final VoidCallback? onLogin;
  final String? message;

  const WelcomeWidget({super.key, this.onLogin, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          SizedBox(
            width: 120,
            height: 120,
            child: Image.asset('assets/images/icon.png'),
          ),
          const SizedBox(height: 32),
          // Title
          Text(
            "Welcome to RealizeAlpha",
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              message ?? "Automated Trading & Portfolio Management",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 48),
          // Action Button
          if (onLogin != null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              label: const Text(
                "Link Brokerage Account",
                style: TextStyle(fontSize: 18.0),
              ),
              icon: const Icon(Icons.login),
              onPressed: onLogin,
            ),
        ],
      ),
    );
  }
}
