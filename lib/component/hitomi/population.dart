// This source code is a part of Project Violet.
// Copyright (C) 2020-2021.violet-team. Licensed under the Apache-2.0 License.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:violet/database/query.dart';

class Population {
  static Map<int, int> population;

  static Future<void> init() async {
    final data =
        await rootBundle.loadString('assets/locale/rank/population.json');

    List<dynamic> _population = json.decode(data);
    population = Map<int, int>();

    for (int i = 0; i < _population.length; i++) {
      population[_population[i] as int] = i;
    }
  }

  static void sortByPopulation(List<QueryResult> qr) {
    qr.sort((x, y) => compare(x, y));
  }

  static int compare(QueryResult a, QueryResult b) {
    // newest article always displayed on the bottom
    if (!population.containsKey(a.id())) {
      // a == b
      if (!population.containsKey(b.id())) return 0;
      // a > b
      return 1;
    }
    // a < b
    if (!population.containsKey(b.id())) return -1;

    return population[a.id()].compareTo(population[b.id()]);
  }
}
