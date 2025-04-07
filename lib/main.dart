import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

// Entry point widget
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthWrapper(),
    );
  }
}

// Wrapper to toggle between login and task screen
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(child: CircularProgressIndicator());
        if (snapshot.hasData)
          return TaskListScreen();
        else
          return AuthScreen();
      },
    );
  }
}

// 🔐 Auth Screen for Login/Register
class AuthScreen extends StatefulWidget {
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool isLogin = true;
  String error = '';

  void _submit() async {
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => error = e.message ?? 'Auth error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (error.isNotEmpty) Text(error, style: TextStyle(color: Colors.red)),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Password'),
            ),
            ElevatedButton(
              onPressed: _submit,
              child: Text(isLogin ? 'Login' : 'Register'),
            ),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin
                  ? "Don't have an account? Register"
                  : "Already have an account? Login"),
            ),
          ],
        ),
      ),
    );
  }
}

// 🧠 TASK LIST SCREEN (same as before but with logout)
class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser!.uid;

  void _addTask(String title) {
    if (title.isEmpty) return;

    _firestore.collection('tasks').add({
      'title': title,
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': userId,
    });

    _taskController.clear();
  }

  void _toggleComplete(String id, bool value) {
    _firestore.collection('tasks').doc(id).update({'completed': value});
  }

  void _deleteTask(String id) {
    _firestore.collection('tasks').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks'),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          // Add task input
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: InputDecoration(hintText: 'Enter task name'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _addTask(_taskController.text),
                )
              ],
            ),
          ),
          // Task list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('tasks')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();

                final tasks = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];

                    return ExpansionTile(
                      leading: Checkbox(
                        value: task['completed'],
                        onChanged: (value) =>
                            _toggleComplete(task.id, value!),
                      ),
                      title: Text(
                        task['title'],
                        style: TextStyle(
                          decoration: task['completed']
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => _deleteTask(task.id),
                      ),
                      children: [
                        SubtaskList(taskId: task.id),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 🔁 SubtaskList remains same as before (you already have it)
class SubtaskList extends StatefulWidget {
  final String taskId;
  const SubtaskList({required this.taskId});

  @override
  State<SubtaskList> createState() => _SubtaskListState();
}

class _SubtaskListState extends State<SubtaskList> {
  final TextEditingController _subtaskController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _addSubtask(String title) {
    if (title.isEmpty) return;

    _firestore
        .collection('tasks')
        .doc(widget.taskId)
        .collection('subtasks')
        .add({
      'title': title,
      'completed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _subtaskController.clear();
  }

  void _toggleSubtaskComplete(String id, bool value) {
    _firestore
        .collection('tasks')
        .doc(widget.taskId)
        .collection('subtasks')
        .doc(id)
        .update({'completed': value});
  }

  void _deleteSubtask(String id) {
    _firestore
        .collection('tasks')
        .doc(widget.taskId)
        .collection('subtasks')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Subtask input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subtaskController,
                  decoration: InputDecoration(hintText: 'Add subtask'),
                ),
              ),
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () => _addSubtask(_subtaskController.text),
              ),
            ],
          ),
        ),
        // Subtask list
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('tasks')
              .doc(widget.taskId)
              .collection('subtasks')
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return SizedBox();

            final subtasks = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: subtasks.length,
              itemBuilder: (context, index) {
                final subtask = subtasks[index];
                return ListTile(
                  leading: Checkbox(
                    value: subtask['completed'],
                    onChanged: (value) =>
                        _toggleSubtaskComplete(subtask.id, value!),
                  ),
                  title: Text(
                    subtask['title'],
                    style: TextStyle(
                      decoration: subtask['completed']
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () => _deleteSubtask(subtask.id),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
