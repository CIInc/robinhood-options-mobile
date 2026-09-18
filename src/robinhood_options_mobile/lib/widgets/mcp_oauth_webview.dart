import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class McpOAuthWebViewPage extends StatefulWidget {
  final String initialUrl;
  final String redirectUri;

  const McpOAuthWebViewPage({
    super.key,
    required this.initialUrl,
    required this.redirectUri,
  });

  @override
  State<McpOAuthWebViewPage> createState() => _McpOAuthWebViewPageState();
}

class _McpOAuthWebViewPageState extends State<McpOAuthWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
            _checkRedirect(url);
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _checkRedirect(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_checkRedirect(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  bool _checkRedirect(String url) {
    if (url.startsWith(widget.redirectUri)) {
      if (mounted) {
        Navigator.of(context).pop(url);
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Robinhood Trading'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
