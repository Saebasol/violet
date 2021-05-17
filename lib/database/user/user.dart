// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';
import 'package:violet/database/database.dart';

class CommonUserDatabase extends DataBaseManager {
  static DataBaseManager _instance;

  static Future<DataBaseManager> getInstance() async {
    if (_instance == null) {
      var dir = await getApplicationDocumentsDirectory();
      _instance = DataBaseManager.create('${dir.path}/user.db');
    }
    return _instance;
  }
}
