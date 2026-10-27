import 'package:flutter/material.dart';
import 'package:akth_posting_web/pages/record_page.dart';
class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

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
                      
                        Row(
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
                      
                      SizedBox(height: 20),
                      InkWell(
                         onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context)=> Record()));
                        },
                        child: Row(
                          
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
                      ),
                      SizedBox(height: 400),
                      InkWell(
                        onTap: () {
                          
                        },
                        child: Row(
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              padding: EdgeInsets.only(top: 30, left: 30,right: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Dashboard",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "AKTH SIWES AUTOMATIC POSTING SYSTEM",
                    style: TextStyle(
                      fontSize: 10,
                      color: const Color.fromARGB(255, 143, 141, 141),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.only(left: 20, top: 10),
                                            
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 40,
                                color: Colors.green,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "0",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Number of Student",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: const Color.fromARGB(255, 143, 141, 141),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Container(
                         
                          height: 150,
                          padding: EdgeInsets.only(left: 20, top: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.other_houses_rounded,
                                color: Colors.green,
                                size: 40,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "4",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                "Available Unit",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: const Color.fromARGB(255, 143, 141, 141),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                  Container(
                    width: 150,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.green,
                    ),
                    child: Center(
                      child: Text(
                        "Generate Posting",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
