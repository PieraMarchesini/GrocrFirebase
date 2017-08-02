/*
 * Copyright (c) 2015 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit

class GroceryListTableViewController: UITableViewController {
  
  // MARK: Constants
  let listToUsers = "ListToUsers"
  
  // MARK: Properties
  var items: [GroceryItem] = []
  var user: User!
  var userCountBarButtonItem: UIBarButtonItem!
  
  let ref = FIRDatabase.database().reference(withPath: "grocery-items")
  let usersRef = FIRDatabase.database().reference(withPath: "online")
  
  // MARK: UIViewController Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.allowsMultipleSelectionDuringEditing = false
    
    userCountBarButtonItem = UIBarButtonItem(title: "1",
                                             style: .plain,
                                             target: self,
                                             action: #selector(userCountButtonDidTouch))
    userCountBarButtonItem.tintColor = UIColor.white
    navigationItem.leftBarButtonItem = userCountBarButtonItem
    
    user = User(uid: "FakeId", email: "hungry@person.food")
    
    //Attach a listener to receive updates whenever the grocery-items endpoint is modified.
    ref.queryOrdered(byChild: "completed").observe(.value, with: { snapshot in
      //Store the latest version of the data in a local variable inside the listener’s closure
      var newItems: [GroceryItem] = []
      
      //The listener’s closure returns a snapshot of the latest set of data. The snapshot contains the entire list of grocery items, not just the updates. Using children, you loop through the grocery items
      for item in snapshot.children {
        //The GroceryItem struct has an initializer that populates its properties using a FIRDataSnapshot. A snapshot’s value is of type AnyObject, and can be a dictionary, array, number, or string. After creating an instance of GroceryItem, it’s added it to the array that contains the latest version of the data
        let groceryItem = GroceryItem(snapshot: item as! FIRDataSnapshot)
        newItems.append(groceryItem)
      }
      
      //Reassign items to the latest version of the data, then reload the table view so it displays the latest version
      self.items = newItems
      self.tableView.reloadData()
      
      //Apenas como log
      print(snapshot.value ?? 0)
    })
    
    FIRAuth.auth()?.addStateDidChangeListener({
      auth, user in
      guard let user = user else { return }
      self.user = User(authData: user)
      
      //Creat a child reference using a user's uid, which is generated when Firebase creates an account
      let currentUserRef = self.usersRef.child(self.user.uid)
      //Use this reference to save the current user's email
      currentUserRef.setValue(self.user.email)
      //Cal onDisconnectRemoveValue() on currentUserRef. This removes the value at the reference's location after the connection to Firebase closes, for instance when a user quits your app. This is perfect for monitoring users who have gone offline
      currentUserRef.onDisconnectRemoveValue()
    })
    
    usersRef.observe(.value, with: {
      snapshot in
      if snapshot.exists() {
        self.userCountBarButtonItem.title = snapshot.childrenCount.description
      } else {
        self.userCountBarButtonItem.title = "0"
      }
    })
  }
  
  // MARK: UITableView Delegate methods
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return items.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
    let groceryItem = items[indexPath.row]
    
    cell.textLabel?.text = groceryItem.name
    cell.detailTextLabel?.text = groceryItem.addedByUser
    
    toggleCellCheckbox(cell, isCompleted: groceryItem.completed)
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let groceryItem = items[indexPath.row]
      groceryItem.ref?.removeValue()
      //items.remove(at: indexPath.row)
      //tableView.reloadData()
    }
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    //Find the cell the user tapped
    guard let cell = tableView.cellForRow(at: indexPath) else { return }
    //Get the corresponding GroceryItem by using index path's row
    let groceryItem = items[indexPath.row]
    //Negate completed on the grocery item to toggle status
    let toggledCompletion = !groceryItem.completed
    //Call toggleCellCheckbox(_:isCompleted:) to update the visual properties of the cell
    toggleCellCheckbox(cell, isCompleted: toggledCompletion)
    //Use updateChildValues(_:) passing a dictionary to update Firebase. This method is different than setValue(_:) because it only applies updates, whereas setValue(_:) is destructive and replaces the entire value at that reference
    groceryItem.ref?.updateChildValues([
      "completed" : toggledCompletion
      ])
  }
  
  func toggleCellCheckbox(_ cell: UITableViewCell, isCompleted: Bool) {
    if !isCompleted {
      cell.accessoryType = .none
      cell.textLabel?.textColor = UIColor.black
      cell.detailTextLabel?.textColor = UIColor.black
    } else {
      cell.accessoryType = .checkmark
      cell.textLabel?.textColor = UIColor.gray
      cell.detailTextLabel?.textColor = UIColor.gray
    }
  }
  
  // MARK: Add Item
  
  @IBAction func addButtonDidTouch(_ sender: AnyObject) {
    let alert = UIAlertController(title: "Grocery Item",
                                  message: "Add an Item",
                                  preferredStyle: .alert)
    
    let saveAction = UIAlertAction(title: "Save",
                                   style: .default)
    { _ in
      //Get the text field (and its text) from the alert controller, this avoid the force unwrap
      guard let textField = alert.textFields?.first,
        let text = textField.text else { return }
      
      //Using the current user's data, create a new GroceryItem that is not completed by default
      let groceryItem = GroceryItem(name: text,
                                    addedByUser: self.user.email,
                                    completed: false)
      
      //Create a child reference using child(_:). The key value of this reference is the item's name in lowercase, so when users add duplicate items (even if they capitalize it, or use mixed case) the database saves only the latest entry
      let groceryItemRef = self.ref.child(text.lowercased())
      
      //User setValue(_:) to save data to the database. This method expects a Dictionary.GroceryItem has a helper function called toAnyObject() to turn it into a Dictionary
      groceryItemRef.setValue(groceryItem.toAnyObject())
      
      //self.items.append(groceryItem)
      //self.tableView.reloadData()
    }
    
    let cancelAction = UIAlertAction(title: "Cancel",
                                     style: .default)
    
    alert.addTextField()
    
    alert.addAction(saveAction)
    alert.addAction(cancelAction)
    
    present(alert, animated: true, completion: nil)
  }
  
  func userCountButtonDidTouch() {
    performSegue(withIdentifier: listToUsers, sender: nil)
  }
  
}
