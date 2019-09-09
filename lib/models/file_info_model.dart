class FileInfo {
  final String path; // File absolute path
  final String name; // File name
  final bool isDir; // Is this file a directory ?
  final int size; // File size

  FileInfo(this.path, this.name, this.isDir, this.size);

  factory FileInfo.fromJson(String directory, Map<String, dynamic> json) {
    return FileInfo(
      directory + "/" + json["name"],
      json["name"],
      json["is_dir"],
      json["size"],
    );
  }
}
