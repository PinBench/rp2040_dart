//   dart run tool/bench_py.dart [image.uf2]
import '../example/load_flash.dart';
import 'bench/workload.dart';

void main(List<String> args) {
  runWorkload(
    (mcu) =>
        loadUF2(args.isEmpty ? 'reference/micropython.uf2' : args.first, mcu),
  );
}
