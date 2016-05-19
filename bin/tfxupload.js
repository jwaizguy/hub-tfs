/*******************************************************************************
 * Copyright (C) 2016 Black Duck Software, Inc.
 * http://www.blackducksoftware.com/
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements. See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership. The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 *******************************************************************************/

var path = require("path"),
  fs = require("fs"),
  Q = require ("q"),
  exec = Q.nfbind(require("child_process").exec);

function installTasks() {
    var promise = Q();
    var tasksPath = path.join(process.cwd(), 'Tasks');
    var tasks = fs.readdirSync(tasksPath);
    console.log(tasks.length + ' tasks found.')
    tasks.forEach(function(task) {
        promise = promise.then(function() {
                console.log('Processing task ' + task);
                process.chdir(path.join(tasksPath,task));
                return npmInstall();
            });

        if (process.argv.indexOf("--installonly") == -1) {
            promise = promise.then(tfxUpload);
        }
    });    
    return promise;
}

function npmInstall() {
  console.log("Installing npm dependencies for task...");
  return exec("npm install --only=prod").then(logExecReturn);
}

function tfxUpload() {
  console.log("Transferring...")
  return exec("tfx build tasks upload --task-path . --overwrite true").then(logExecReturn);
}

function logExecReturn(result) {
  console.log(result[0]);
  if (result[1] !== "") {
    console.error(result[1]);
  }
}

installTasks()
  .done(function() {
    console.log("Upload complete!");
  }, function(input) {
    console.log("Upload failed!");
  });