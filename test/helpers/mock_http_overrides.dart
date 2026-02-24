import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

class MockFontHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => MockHttpClientRequest();
  
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => MockHttpClientRequest();

  @override
  set autoUncompress(bool value) {}
  
  @override
  bool get autoUncompress => true;

  @override
  void close({bool force = false}) {}

  @override
  set userAgent(String? value) {}
  
  @override
  String? get userAgent => 'dart-test';
}

class MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;
  @override
  int contentLength = 0;
  @override
  bool bufferOutput = true;
  
  @override
  Encoding encoding = utf8;

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => MockHttpClientResponse();

  @override
  void add(List<int> data) {}

  @override
  void write(Object? obj) {}
  
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain();
  }
  
  @override
  Future<HttpClientResponse> get done async => MockHttpClientResponse();
}

class MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => 0;
  
  @override
  bool get isRedirect => false;
  
  @override
  bool get persistentConnection => true;
  
  @override
  String get reasonPhrase => 'OK';
  
  @override
  List<RedirectInfo> get redirects => [];

  @override
  HttpHeaders get headers => MockHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.fromIterable([]).listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Future<S> fold<S>(S initialValue, S Function(S previous, List<int> element) combine) async {
    return initialValue;
  }

  @override
  Future<List<List<int>>> toList() async => [];

  @override
  Future<bool> get isEmpty async => true;
  
  @override
  Future<bool> any(bool Function(List<int> element) test) async => false;
}

class MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  set contentType(ContentType? value) {}
  
  @override
  List<String>? operator [](String name) => [];

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  
  @override
  void removeAll(String name) {}
  
  @override
  void forEach(void Function(String name, List<String> values) action) {}
}
