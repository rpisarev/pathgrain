import 'dart:convert';
import 'dart:io';

import 'package:pathgrain/walks/analysis/surface_diagnostics.dart';
import 'package:pathgrain/walks/analysis/surface_replay.dart';

import 'capture_input.dart';

const _usage = '''Run from the repository root (Dart SDK, no live provider):
dart tool/replay_surface.dart --input INPUT.json --output REPORT.json
dart tool/replay_surface.dart --walk-db WALK.sqlite --cache-db CACHE.sqlite --walk-id ID --output REPORT.json
Optional: --namespace VALUE (capture only), --save-input LOCAL.json, --revision LABEL
Outputs are local and sensitive. Existing files are not overwritten.
''';

Future<void> main(List<String> args) async {
  if (args.length == 1 && args.single == '--help') {
    stdout.write(_usage);
    return;
  }
  try {
    final options = <String, String>{};
    const allowed = {
      '--input',
      '--output',
      '--walk-db',
      '--cache-db',
      '--walk-id',
      '--namespace',
      '--save-input',
      '--revision',
    };
    for (var i = 0; i < args.length; i += 2) {
      if (i + 1 >= args.length ||
          !allowed.contains(args[i]) ||
          options.containsKey(args[i])) {
        throw const FormatException('Invalid or repeated option');
      }
      options[args[i]] = args[i + 1];
    }
    final output = options['--output'];
    final inputPath = options['--input'];
    final captureOptions = ['--walk-db', '--cache-db', '--walk-id'];
    if (output == null ||
        (inputPath == null
            ? !captureOptions.every(options.containsKey)
            : [...captureOptions, '--namespace'].any(options.containsKey))) {
      throw const FormatException(
        'Specify input JSON or all three capture options, and output',
      );
    }
    final paths = [
      output,
      if (options['--save-input'] case final String path) path,
    ];
    if (paths.map((p) => File(p).absolute.path).toSet().length !=
            paths.length ||
        paths.any(
          (p) =>
              FileSystemEntity.typeSync(p, followLinks: false) !=
              FileSystemEntityType.notFound,
        )) {
      throw const FormatException('Output paths must be distinct new files');
    }
    final input = inputPath != null
        ? SurfaceReplayInput.fromJson(
            jsonDecode(await File(inputPath).readAsString())
                as Map<String, dynamic>,
          )
        : (await readSurfaceCapture(
            walkDatabase: options['--walk-db']!,
            evidenceDatabase: options['--cache-db']!,
            walkId: int.parse(options['--walk-id']!),
            namespace: options['--namespace'],
          )).input;
    final result = SurfaceReplay.run(input);
    if (options['--save-input'] case final String path) {
      await File(path).writeAsString('${diagnosticJson(input.toJson())}\n');
    }
    await File(output).writeAsString(
      '${diagnosticJson(result.toJson(implementationRevision: options['--revision']))}\n',
    );
    stdout.writeln(diagnosticJson(result.diagnostics.aggregate.toJson()));
  } on Object catch (error) {
    stderr.writeln(
      'Replay failed (${error.runtimeType}). Check inputs and local output paths.',
    );
    if (error is FormatException) stderr.writeln(error.message);
    stderr.write(_usage);
    exitCode = 1;
  }
}
