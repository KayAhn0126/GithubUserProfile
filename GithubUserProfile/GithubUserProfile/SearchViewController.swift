//
//  SearchViewController.swift
//  GithubUserSearch
//
//

import UIKit
import Combine
import Kingfisher

class UserProfileViewController: UIViewController {
    @Published private(set) var user: UserProfile?
    var subscriptions = Set<AnyCancellable>()
    
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var loginLabel: UILabel!
    @IBOutlet weak var followerLabel: UILabel!
    @IBOutlet weak var followingLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        embendSearchControl()
        bind()
    }
    
    
    
    // network
    
    // setupUI
    private func setupUI() {
        thumbnail.layer.cornerRadius = 80
    }
    
    // search control
    private func embendSearchControl() {
        self.navigationItem.title = "Search"
        
        let searchController = UISearchController(searchResultsController: nil)
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = "kayahn0126"
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        self.navigationItem.searchController = searchController
    }
    
    // bind
    private func bind() {
        $user
            .receive(on: RunLoop.main)
            .sink { [unowned self] result in
                self.update(result)
            }.store(in: &subscriptions)
    }
    
    private func update(_ user: UserProfile?) {}
}

extension UserProfileViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let keyword = searchController.searchBar.text
        
        print("search: \(keyword)")
    }
}

extension UserProfileViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        print("button clicked: \(searchBar.text)")
    }
}
