/// Hari epoch (jumlah hari sejak 1970-01-01 UTC) dari sebuah [DateTime].
int epochDay(DateTime time) =>
    time.toUtc().difference(DateTime.utc(1970)).inDays;
