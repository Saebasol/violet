// This source code is a part of Project Violet.
// Copyright (C) 2020. violet-team. Licensed under the MIT License.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class DataBaseManager {
  String dbPath;
  Database db;
  static DataBaseManager _instance;

  DataBaseManager({this.dbPath});

  static DataBaseManager create(String dbPath) {
    return new DataBaseManager(dbPath: dbPath);
  }

  @protected
  @mustCallSuper
  void dispose() async {
    await _close();
  }

  static Future<DataBaseManager> getInstance() async {
    if (_instance == null) {
      _instance =
          create((await SharedPreferences.getInstance()).getString('db_path'));
      await _instance._open();
    }
    return _instance;
  }

  Future _open() async {
    db = await openDatabase(dbPath);
  }

  Future _close() async {
    await db.close();
  }

  Future<List<Map<String, dynamic>>> query(String str) async {
    // await _open();
    var rr = await db.rawQuery(str);
    // await _close();
    return rr;
  }

  Future<void> execute(String str) async {
    // await _open();
    await db.execute(str);
    // await _close();
  }

  Future<void> insert(String name, Map<String, dynamic> wh) async {
    await db.insert(name, wh);
  }

  Future<void> update(String name, Map<String, dynamic> wh) async {
    await db.update(name, wh);
  }

  Future<bool> test() async {
    try {
      final x = await query('SELECT count(*) FROM HitomiColumnModel');
      if ((x[0]['count(*)'] as int) < 500000) return false;
      return true;
    } catch (e) {
      return false;
    }
  }
}

class QueryResult {
  Map<String, dynamic> result;
  QueryResult({this.result});

  int id() => result['Id'];
  title() => result['Title'];
  ehash() => result['EHash'];
  type() => result['Type'];
  artists() => result['Artists'];
  characters() => result['Characters'];
  groups() => result['Groups'];
  language() => result['Language'];
  series() => result['Series'];
  tags() => result['Tags'];
  uploader() => result['Uploader'];
  published() => result['Published'];
  files() => result['Files'];
  classname() => result['Class'];

  DateTime getDateTime() {
    if (published() == null || published() == 0) return null;

    const epochTicks = 621355968000000000;
    const ticksPerMillisecond = 10000;

    var ticksSinceEpoch = (published() as int) - epochTicks;
    var ms = ticksSinceEpoch / ticksPerMillisecond;
    return DateTime.fromMillisecondsSinceEpoch(ms as int);
  }
}

class QueryManager {
  String queryString;
  List<QueryResult> results;
  bool isPagination;
  int curPage;
  int itemsPerPage = 500;

  static Future<QueryManager> query(String rawQuery) async {
    QueryManager qm = new QueryManager();
    qm.queryString = rawQuery;
    qm.results = (await (await DataBaseManager.getInstance()).query(rawQuery))
        .map((e) => QueryResult(result: e));
    return qm;
  }

  static QueryManager queryPagination(String rawQuery) {
    QueryManager qm = new QueryManager();
    qm.isPagination = true;
    qm.curPage = 0;
    qm.queryString = rawQuery;
    return qm;
  }

  Future<List<QueryResult>> next() async {
    curPage += 1;
    return (await (await DataBaseManager.getInstance()).query(
            "$queryString ORDER BY Id DESC LIMIT $itemsPerPage OFFSET ${itemsPerPage * (curPage - 1)}"))
        .map((e) => QueryResult(result: e))
        .toList();
  }
}
