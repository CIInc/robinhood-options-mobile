import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart' as mcp;

void main() {
  group('RobinhoodMcpClient Implementation Tests', () {
    test('Implementation serializes with valid absolute websiteUrl', () {
      const impl = mcp.Implementation(
        name: 'RealizeAlpha MCP Client',
        title: 'RealizeAlpha MCP Client',
        version: '1.0.0',
        description: 'RealizeAlpha MCP Client for Robinhood Agentic Trading',
        websiteUrl: 'https://github.com/CIInc/robinhood-options-mobile',
      );

      final json = impl.toJson();
      expect(json['name'], 'RealizeAlpha MCP Client');
      expect(json['title'], 'RealizeAlpha MCP Client');
      expect(json['version'], '1.0.0');
      expect(json['websiteUrl'],
          'https://github.com/CIInc/robinhood-options-mobile');
    });

    test('Implementation throws if websiteUrl is empty string', () {
      const invalidImpl = mcp.Implementation(
        name: 'RealizeAlpha MCP Client',
        title: 'RealizeAlpha MCP Client',
        version: '1.0.0',
        description: 'RealizeAlpha MCP Client for Robinhood Agentic Trading',
        websiteUrl: '',
      );

      expect(
        () => invalidImpl.toJson(),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('must be an absolute URI'),
        )),
      );
    });

    test('McpClient initializes successfully with valid Implementation', () {
      final client = mcp.McpClient(
        const mcp.Implementation(
          name: 'RealizeAlpha MCP Client',
          title: 'RealizeAlpha MCP Client',
          version: '1.0.0',
          description: 'RealizeAlpha MCP Client for Robinhood Agentic Trading',
          websiteUrl: 'https://github.com/CIInc/robinhood-options-mobile',
        ),
        options: mcp.McpClientOptions(
          capabilities: mcp.ClientCapabilities(),
        ),
      );

      expect(client, isNotNull);
    });
  });
}
