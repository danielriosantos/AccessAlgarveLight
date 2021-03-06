//
//  CreateAccountViewController.swift
//  Access Algarve Light
//
//  Created by Daniel Santos on 19/03/2018.
//  Copyright © 2018 Daniel Santos. All rights reserved.
//

import UIKit
import SVProgressHUD
import SwiftyJSON
import QuartzCore
import FBSDKLoginKit

class CreateAccountViewController: UIViewController, UITextFieldDelegate, UIPickerViewDataSource, UIPickerViewDelegate, FBSDKLoginButtonDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet var email: UITextField!
    @IBOutlet var password: UITextField!
    @IBOutlet var confirmpassword: UITextField!
    @IBOutlet var name: UITextField!
    @IBOutlet var country: UITextField!
    @IBOutlet var createButton: UIButton!
    @IBOutlet weak var countryPickerView: UIView!
    @IBOutlet weak var countryPicker: UIPickerView!
    
    var user: User!
    var countries: JSON!
    
    let fbLoginButton: FBSDKLoginButton = {
        let button = FBSDKLoginButton()
        button.readPermissions = ["public_profile", "email"]
        return button
    }()
    
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!) {
        print("FB Account Logged Out")
    }
    
    func loginButton(_ loginButton: FBSDKLoginButton!, didCompleteWith result: FBSDKLoginManagerLoginResult!, error: Error!) {
        if error != nil {
            print(error)
            return
        }
        DispatchQueue.main.async {SVProgressHUD.show(withStatus: "Logging In")}
        fetchProfile()
        print("FB Login Success")
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Try to find next responder
        if let nextField = textField.superview?.viewWithTag(textField.tag + 1) as? UITextField {
            nextField.becomeFirstResponder()
        } else {
            // Not found, so remove keyboard.
            textField.resignFirstResponder()
        }
        // Do not add a line break
        return false
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.countries.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.countries[row]["name"]["common"].string
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.country.text = self.countries[row]["name"]["common"].string
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboards))
        
        view.addGestureRecognizer(tap)
        
        self.countryPicker.delegate = self
        self.countryPicker.dataSource = self
        fbLoginButton.delegate = self
        self.scrollView.addSubview(fbLoginButton)
        fbLoginButton.frame = CGRect(x: 0, y: createButton.frame.origin.y + createButton.frame.height + 65, width: 190, height: 35)
        fbLoginButton.center.x = self.view.center.x
        
        //Load coutries file
        if let path = Bundle.main.path(forResource: "countries", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                let jsonCountries = try JSON(data: data)
                self.countries = jsonCountries
            } catch {
                print("Error getting countries from JSON file")
            }
        }
        
    }
    
    @objc func dismissKeyboards() {
        self.view.endEditing(true)
        self.countryPickerView.isHidden = true
    }
    
    func fetchProfile() {
        let params = ["fields": "id, name, email, first_name, last_name, age_range, link, gender, locale, timezone, picture.type(large), updated_time, verified"]
        FBSDKGraphRequest(graphPath: "me", parameters: params).start(completionHandler: {
            (connection, result, error) in
            
            if let error = error {
                DispatchQueue.main.async {SVProgressHUD.dismiss()}
                print(error.localizedDescription)
            } else {
                let json = JSON(result!)
                print(json)
                let email = json["email"].stringValue
                
                //: Check if user exists in database, otherwise create it
                self.getAPIResults(endpoint: "users", parameters: ["email": email]) {data in
                    do {
                        let users: [User] = try [User].decode(data: data)
                        if users.count > 0 {
                            self.user = users[0]
                            self.user.status = 1
                            //: Save user status on UserDefaults
                            let encodedUser = try self.user.encode()
                            let defaults = UserDefaults.standard
                            defaults.set(encodedUser, forKey: "SavedUser")
                            DispatchQueue.main.async {
                                SVProgressHUD.dismiss()
                                let params = ["status": 1]
                                self.putAPIResults(endpoint: "users/" + String(self.user.id), parameters: params) {_ in}
                                self.performSegue(withIdentifier: "createAccountSegue", sender: self)
                            }
                        } else {
                            //: User does not exist, use facebook data to create it and log in
                            let params = [
                                "name": json["name"].stringValue,
                                "email": json["email"].stringValue
                            ]
                            self.postAPIResults(endpoint: "users", parameters: params) { data in
                                DispatchQueue.main.async {
                                    do {
                                        //: Save user in app defaults
                                        self.user = try User.decode(data: data)
                                        //self.user.status = 0
                                        //self.user.country = self.country.text
                                        let defaults = UserDefaults.standard
                                        let encodedUser = try self.user.encode()
                                        defaults.set(encodedUser, forKey: "SavedUser")
                                        SVProgressHUD.dismiss()
                                        self.performSegue(withIdentifier: "createAccountSegue", sender: self)
                                    } catch {
                                        //: Alert wrong user pass message
                                        SVProgressHUD.dismiss()
                                        let alert = UIAlertController(title: "Error", message: "Error Creating Your Account. The account you're trying to create might already exist or please try again.", preferredStyle: UIAlertControllerStyle.alert)
                                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                                        self.present(alert, animated: true, completion: nil)
                                    }
                                }
                            }
                        }
                    } catch {
                        //: Authentication was wrong, alert user
                        DispatchQueue.main.async {
                            SVProgressHUD.dismiss()
                            let alert = UIAlertController(title: "Error", message: "There was an eror logging in with your facebook, please try again later", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                }
                
            }
            
            
        })
    }
    
    @IBAction func createAccount(_ sender: Any) {
        //self.performSegue(withIdentifier: "createAccountSegue", sender: self)
        if password.text!.count > 7 {
            if password.text == confirmpassword.text {
                DispatchQueue.main.async {SVProgressHUD.show(withStatus: "Loading")}
                let params = [
                    "name": name.text!,
                    "email": email.text!,
                    "password": password.text!,
                    "country": country.text!
                ]
                postAPIResults(endpoint: "users", parameters: params) { data in
                    DispatchQueue.main.async {
                        do {
                            //: Save user in app defaults
                            self.user = try User.decode(data: data)
                            //self.user.status = 0
                            //self.user.country = self.country.text
                            let defaults = UserDefaults.standard
                            let encodedUser = try self.user.encode()
                            defaults.set(encodedUser, forKey: "SavedUser")
                            SVProgressHUD.dismiss()
                            self.performSegue(withIdentifier: "createAccountSegue", sender: self)
                        } catch {
                            //: Alert wrong user pass message
                            SVProgressHUD.dismiss()
                            let alert = UIAlertController(title: "Error", message: "Error Creating Your Account. The account you're trying to create might already exist or please try again.", preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                }
            } else {
                let alert = UIAlertController(title: "Error", message: "The passwords do not match", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        } else {
            let alert = UIAlertController(title: "Error", message: "The passwords needs to contain at least 8 characters", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBAction func editingDidBegin(_ sender: UITextField) {
        if sender.tag == 5 {
            sender.resignFirstResponder()
            sender.superview?.endEditing(true)
            var selectedRow: Int!
            for (index, country) in (self.countries.array?.enumerated())! {
                if country["name"]["common"].string == sender.text {
                    selectedRow = index
                }
            }
            if selectedRow != nil {self.countryPicker.selectRow(selectedRow, inComponent: 0, animated: true)}
            self.countryPickerView.isHidden = false
        }
    }
    @IBAction func closeCountryPickerClicked(_ sender: UIButton) {
        self.countryPickerView.isHidden = true
    }
    
}
