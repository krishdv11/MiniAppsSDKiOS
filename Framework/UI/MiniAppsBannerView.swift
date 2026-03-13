
import UIKit

/// A view that displays mini app banners in a horizontally scrollable collection view
public class MiniAppsBannerView: UIView {
    
    private var collectionView: UICollectionView!
    private var miniApps: [MiniApp] = []
    
    /// Callback when a banner is tapped
    public var onBannerTapped: ((MiniApp) -> Void)?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        // Configure collection view layout for horizontal scrolling
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        
        // Create collection view
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Register cell
        collectionView.register(BannerCollectionViewCell.self, forCellWithReuseIdentifier: "BannerCell")
        
        addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    /// Configures the banner view with an array of mini apps
    /// - Parameter miniApps: Array of mini apps to display
    public func configure(with miniApps: [MiniApp]) {
        self.miniApps = miniApps
        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource
extension MiniAppsBannerView: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return miniApps.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BannerCell", for: indexPath) as! BannerCollectionViewCell
        cell.configure(with: miniApps[indexPath.item])
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension MiniAppsBannerView: UICollectionViewDelegateFlowLayout {
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Each cell takes up screen width minus 20px (10px on each side)
        let screenWidth = UIScreen.main.bounds.width
        let width = screenWidth - 100 // 10px leading + 10px trailing
        let height = collectionView.frame.height
        return CGSize(width: width, height: height)
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let miniApp = miniApps[indexPath.item]
        onBannerTapped?(miniApp)
    }
}

// MARK: - Banner Cell
private class BannerCollectionViewCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        titleLabel.text = nil
        imageView.backgroundColor = .lightGray
        updateImageCornerRadius()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateImageCornerRadius()
    }
    
    private func updateImageCornerRadius() {
        // Apply corner radius to bottom corners of imageView
        imageView.layer.cornerRadius = 8
        imageView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner] // Bottom left and bottom right
        imageView.layer.masksToBounds = true
    }
    
    private func setup() {
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .lightGray
        
        // Apply corner radius to imageView bottom corners
        imageView.layer.cornerRadius = 8
        imageView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner] // Bottom left and bottom right
        imageView.layer.masksToBounds = true
        
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 1
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 150),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with miniApp: MiniApp) {
        // Set title from miniApp.name
        titleLabel.text = miniApp.name
        
        // Reset image before loading new one
        imageView.image = nil
        
        // Load image asynchronously from iconUrl
        if !miniApp.iconUrl.isEmpty {
            loadImage(from: miniApp.iconUrl)
        }
    }
    
    private func loadImage(from urlString: String) {
        guard let imageURL = URL(string: urlString) else {
            print("Invalid image URL: \(urlString)")
            return
        }
        
        // Create a URLSession configuration
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        
        let session = URLSession(configuration: configuration)
        
        session.dataTask(with: imageURL) { [weak self] data, response, error in
            if let error = error {
                print("Error loading image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.imageView.backgroundColor = .lightGray
                }
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                print("Failed to create image from data")
                DispatchQueue.main.async {
                    self?.imageView.backgroundColor = .lightGray
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.imageView.image = image
                self?.imageView.backgroundColor = .clear
            }
        }.resume()
    }
}
