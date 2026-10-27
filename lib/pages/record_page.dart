import 'package:flutter/material.dart';
import 'package:akth_posting_web/student.dart';
class Record extends StatefulWidget {
  const Record({super.key});

  @override
  State<Record> createState() => _RecordState();
}

class _RecordState extends State<Record> {

  void addStudent() {
    
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(248, 248, 248, 1),
      body: Row(
        children: [
          Container(
            width: 200,
            color: Colors.white,
            //Column below is the parent widget and every parent set Contraints or rules
            // I had a problem with positioning my two text fields and later found it is because,
            // of the parent widget set Constarints to its child.
            //I tackle the issue and set the correct spacing
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20, left: 5),

                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "AKTH",
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.green,
                            fontWeight: FontWeight.w100,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Siwes posting System",
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color.fromARGB(255, 143, 141, 141),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 50),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Row(
                          children: [
                            Icon(
                              Icons.dashboard_outlined,
                              color: Colors.green,
                              size: 30,
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Dashboard",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: Colors.green,
                            size: 30,
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Record",

                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 400),
                      Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red, size: 30),
                          SizedBox(width: 10),
                          Text(
                            "Logout",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 30,right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Student Registry",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  "Add and Manage Siwes Student",
                  style: TextStyle(
                    color: const Color.fromARGB(255, 143, 141, 141),
                  ),
                ),
                SizedBox(height: 30),
                Container(
                  width: 1000,
                  height: 230,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 15,
                      top: 20,
                      right: 15,
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Add New Student",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Name",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 5),
                                Container(
                                  width: 200,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black26),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: TextField(decoration: null),
                                ),

                                SizedBox(width: 40),

                                Text(
                                  "Phone Number",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 5),
                                Container(
                                  width: 200,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black26),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: TextField(decoration: null),
                                ),
                              ],
                            ),

                            SizedBox(height: 10),

                            Row(
                              children: [
                                Text(
                                  "Group",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(width: 5),
                                Container(
                                  width: 200,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.black26),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: TextField(decoration: null),
                                ),
                              ],
                            ),

                            // SizedBox(width: 10),
                            // Column(
                            //   crossAxisAlignment: CrossAxisAlignment.start,
                            //   children: [
                            //     Text("Schedule of Duty",style: TextStyle(fontWeight: FontWeight.bold),),
                            //     Container(
                            //       width: 150,
                            //       height: 30,
                            //       decoration: BoxDecoration(
                            //         border: Border.all(color: Colors.black26),
                            //         borderRadius: BorderRadius.circular(6),
                            //       ),
                            //        child: TextField(
                            //         decoration: null,
                            //       ),
                            //     ),
                            //   ],
                            // ),
                          ],
                        ),
                        SizedBox(height: 20),

                        Row(
                          children: [
                            InkWell(
                              onTap: () {},
                              child: Container(
                                width: 150,
                                height: 50,
                                padding: EdgeInsets.only(left: 18),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black26),
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.green,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.add, color: Colors.white),
                                    Text(
                                      "Add Student",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 40),
                Container(
                  width: 1000,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20, top: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Total Students:0"),
                        SizedBox(height: 10),
                        Container(
                          width: 900,
                          height: 50,
                          padding: EdgeInsets.only(left: 20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "S/N",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 40),
                              Text(
                                "Name",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 60),
                              Text(
                                "Phone Number",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 60),
                              Text(
                                "Group",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 60),
                              Text(
                                "Posting",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 60),
                              Text(
                                "Schedule of Duty",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 40),
                        Center(
                          child: Icon(
                            Icons.note_alt_outlined,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 10),
                        Center(
                          child: Text(
                            "No Records Yet",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
