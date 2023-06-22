//
//  UploadHandler.swift
//  Linke
//
//  Created by Hanyi Liu on 5/21/23.
//


import Foundation
import FirebaseFirestore


//import FirebaseFirestore
struct UploadHandler: Any {
    
    //static let projectID = "linker-1670345942069"
    static let datasetID = "student_data"
    
    static let db = Firestore.firestore()
    
    
    ///Given student and their classrooms, return a JSON file that will be uploaded to the database.
    static func createStudentDictionary(studentName: String, studentID: String, studentEmail: String, classrooms: ClassroomAPI) -> [String: Any]? {
        var studentDictionary: [String: Any] = [:]
        studentDictionary["name"] = studentName
        studentDictionary["id"] = studentID
        studentDictionary["email"] = studentEmail
        studentDictionary["last_updated"] = Date()

        var classroomArray: [[String: Any]] = []
        for classroom in classrooms.getVisibleClassrooms() {
            var classroomDictionary: [String: Any] = [:]
            classroomDictionary["name"] = classroom.getName()
            classroomDictionary["id"] = classroom.getCourseID()
            classroomDictionary["teacher_id"] = classroom.teacherID
            classroomDictionary["teacher_name"] = classroom.teacherName
            
            var assignmentArray: [[String: Any]] = []

            for assignment in classroom.getAssignments() {
                var assignmentDictionary: [String: Any] = [:]
                assignmentDictionary["name"] = assignment.getName()
                assignmentDictionary["id"] = assignment.getID()
                
                if let date = assignment.getDueDate() {
                    let calendar = Calendar.current
                    let timeZoneOffset = TimeZone.current.secondsFromGMT(for: date)
                    let utcDate = calendar.date(byAdding: .second, value: -timeZoneOffset, to: date)
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: utcDate!)
                    let dueDate: [String: Int] = [
                        "year": components.year!,
                        "month": components.month!,
                        "day": components.day!
                    ]
                    assignmentDictionary["due_date"] = dueDate
                    
                    if let hour = components.hour, let minute = components.minute {
                        let dueTime: [String: Int] = [
                            "hour": hour,
                            "minute": minute
                        ]
                        assignmentDictionary["due_time"] = dueTime
                    }
                    print("Assignment \(assignment.getName())\n     Type: \(assignment.type)\n      Reminder Status: \(assignment.reminderStatus)")
                    if(assignment.type == .completed) {
                        assignmentDictionary["status"] = 1
                    } else if(assignment.reminderStatus == .completed) {
                        assignmentDictionary["status"] = 2
                    } else {
                        assignmentDictionary["status"] = 0
                    }
                }
                
                assignmentArray.append(assignmentDictionary)
            }
            
            classroomDictionary["assignment"] = assignmentArray
            classroomArray.append(classroomDictionary)
        }

        studentDictionary["classroom"] = classroomArray

        return studentDictionary

    }
    
    ///Uploads given student data.
    static func uploadData(data: [String:Any]) {
        print("Trying to upload data to Firestore")
        
        let document = db.collection("student_data").document("\(data["id"]!)")
        document.setData(data)
    }

}
