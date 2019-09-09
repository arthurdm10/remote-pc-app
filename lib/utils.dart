import 'dart:math' as math;

String fileSizeFormated(int size) {
  ///https://stackoverflow.com/questions/3263892/format-file-size-as-mb-gb-etc
  final units = ["B", "kB", "MB", "GB", "TB"];
  final fileSize = size;

  if (fileSize <= 0) {
    return "0 B";
  }
  final digitGroups = math.log(fileSize) ~/ math.log(1024);
  final val = fileSize / math.pow(1024, digitGroups);

  return '${val.toStringAsFixed(2)} ${units[digitGroups]}';
}
