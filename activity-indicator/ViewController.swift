//
//  ViewController.swift
//  activity-indicator
//
//  Created by Kelvin Fok on 2/4/23.
//

import UIKit
import Combine
import ActivityIndicator
import SkeletonView

class ViewModel {

  struct Input {
    let buttonTapPublisher: AnyPublisher<Void, Never>
  }

  struct Output {
    let loadingPublisher: AnyPublisher<Bool, Never>
    let dataSourcePublisher: AnyPublisher<String, Error>
  }

  func transform(input: Input) -> Output {
    let activityIndicator = ActivityIndicator()

    let dataSourcePublisher = input.buttonTapPublisher.flatMap { [weak self] _ in
      return self?.makeSomeAPICall().trackActivity(activityIndicator) ?? Empty().eraseToAnyPublisher()
    }.eraseToAnyPublisher()

    return .init(
      loadingPublisher: activityIndicator.loading.eraseToAnyPublisher(),
      dataSourcePublisher: dataSourcePublisher)
  }

  private func makeSomeAPICall() -> AnyPublisher<String, Error> {
    return Future<String, Error> { [unowned self] promise in
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
        promise(.success(self.randomString(length: 10)))
      })
    }.eraseToAnyPublisher()
  }

  func randomString(length: Int) -> String {
      let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      let allowedCharsCount = UInt32(allowedChars.count)
      var randomString = ""
      for _ in 0 ..< length {
          let randomNum = Int(arc4random_uniform(allowedCharsCount))
          let randomIndex = allowedChars.index(allowedChars.startIndex, offsetBy: randomNum)
          let newCharacter = allowedChars[randomIndex]
          randomString += String(newCharacter)
      }
      return randomString
  }
}

class ViewController: UIViewController {

  private let viewModel = ViewModel()
  private let buttonTapPublisher = PassthroughSubject<Void, Never>()
  private var cancellables = Set<AnyCancellable>()

  @IBOutlet weak var label: UILabel!

  private let loadingView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isSkeletonable = true
    return view
  }()

  override func loadView() {
    super.loadView()
    observe()
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    layout()
  }

  private func layout() {
    view.addSubview(loadingView)
    NSLayoutConstraint.activate([
      loadingView.leadingAnchor.constraint(equalTo: label.leadingAnchor),
      loadingView.trailingAnchor.constraint(equalTo: label.trailingAnchor),
      loadingView.topAnchor.constraint(equalTo: label.topAnchor),
      loadingView.bottomAnchor.constraint(equalTo: label.bottomAnchor)
    ])
  }

  private func observe() {
    let input = ViewModel.Input(buttonTapPublisher: buttonTapPublisher.eraseToAnyPublisher())
    let output = viewModel.transform(input: input)

    output.loadingPublisher
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] isEnabled in
      if isEnabled {
        loadingView.showAnimatedGradientSkeleton(transition: .crossDissolve(0.2))
      } else {
        loadingView.hideSkeleton(transition: .crossDissolve(0.2))
      }
    }.store(in: &cancellables)

    output.dataSourcePublisher
      .receive(on: DispatchQueue.main)
      .sink { completion in
        if case .failure(let error) = completion {
          print(error.localizedDescription)
        }
    } receiveValue: { [weak self] name in
       self?.label.text = name
    }.store(in: &cancellables)
  }

  @IBAction func buttonTapped(_ sender: Any) {
    buttonTapPublisher.send()
  }
}

