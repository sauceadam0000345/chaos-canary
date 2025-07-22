// In ChaosCanary/ViewController.swift

import UIKit

class ViewController: UIViewController {

    // These are connections to the UI elements we will create in the Storyboard.
    @IBOutlet weak var urlTextField: UITextField!
    @IBOutlet weak var statusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Set a default URL to make testing easier.
        urlTextField.text = "https://jsonplaceholder.typicode.com/todos/1"
        statusLabel.text = "Ready"
    }

    // This function will be linked to our "Make Request" button.
    @IBAction func makeRequestButtonTapped(_ sender: UIButton) {
        // When the button is tapped, get the URL from the text field.
        guard let urlString = urlTextField.text, let url = URL(string: urlString) else {
            self.statusLabel.text = "Error: Invalid URL"
            return
        }

        // Update the status label to show we are making a request.
        self.statusLabel.text = "Loading..."
        self.statusLabel.textColor = .gray

        // Create and run the network request.
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            // Ensure we update the UI on the main thread.
            DispatchQueue.main.async {
                if let error = error {
                    self?.statusLabel.text = "Error: \(error.localizedDescription)"
                    self?.statusLabel.textColor = .red
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    // Display the result in the status label.
                    if (200...299).contains(httpResponse.statusCode) {
                        self?.statusLabel.text = "Success: \(httpResponse.statusCode)"
                        self?.statusLabel.textColor = .green
                    } else {
                        self?.statusLabel.text = "Failure: \(httpResponse.statusCode)"
                        self?.statusLabel.textColor = .red
                    }
                }
            }
        }
        task.resume()
    }
}
