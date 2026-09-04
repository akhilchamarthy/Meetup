//
//  CalendarHeatMapView.swift
//  Meetup MessagesExtension
//
//  Created by Akhil Chamarthy on 2/28/26.
//

import UIKit

// MARK: - CalendarHeatMapView

/// A calendar grid that colors each day cell by how many people are available.
/// Drop it into any Auto Layout context; it sizes itself via intrinsicContentSize.
class CalendarHeatMapView: UIView {

    // MARK: - Data

    private var gridItems: [Date?] = []   // nil = empty padding cell
    private var heat: [Date: Int]  = [:]
    private var totalParticipants: Int = 0

    // MARK: - UI

    private let weekHeaderStack: UIStackView = {
        let sv = UIStackView()
        sv.axis         = .horizontal
        sv.distribution = .fillEqually
        sv.translatesAutoresizingMaskIntoConstraints = false
        for name in ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"] {
            let l = UILabel()
            l.text          = name
            l.font          = UIFont.systemFont(ofSize: 11, weight: .semibold)
            l.textColor     = .secondaryLabel
            l.textAlignment = .center
            sv.addArrangedSubview(l)
        }
        return sv
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing      = 4
        layout.sectionInset            = .zero
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor   = .clear
        cv.isScrollEnabled   = false
        cv.dataSource        = self
        cv.delegate          = self
        cv.register(DayCell.self, forCellWithReuseIdentifier: DayCell.id)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private var collectionViewHeight: NSLayoutConstraint!

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        addSubview(weekHeaderStack)
        addSubview(collectionView)

        collectionViewHeight = collectionView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            weekHeaderStack.topAnchor.constraint(equalTo: topAnchor),
            weekHeaderStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            weekHeaderStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            weekHeaderStack.heightAnchor.constraint(equalToConstant: 28),

            collectionView.topAnchor.constraint(equalTo: weekHeaderStack.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionViewHeight,
        ])
    }

    // MARK: - Configuration

    func configure(daysInRange: [Date], heat: [Date: Int], totalParticipants: Int) {
        self.heat              = heat
        self.totalParticipants = totalParticipants
        self.gridItems         = buildGridItems(from: daysInRange)
        collectionView.reloadData()
        updateCollectionHeight()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // Recompute height now that we know our actual width.
        updateCollectionHeight()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    private func cellSide() -> CGFloat {
        let w = bounds.width
        guard w > 0 else { return 40 }
        return floor((w - 6 * 4) / 7)
    }

    private func updateCollectionHeight() {
        let rows    = CGFloat(gridItems.count / 7)
        let newH    = rows > 0 ? rows * cellSide() + max(0, rows - 1) * 4 : 0
        guard abs(collectionViewHeight.constant - newH) > 0.5 else { return }
        collectionViewHeight.constant = newH
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        let rows = CGFloat(gridItems.count / 7)
        let h    = 28 + 4 + rows * cellSide() + max(0, rows - 1) * 4
        return CGSize(width: UIView.noIntrinsicMetric, height: h)
    }

    // MARK: - Grid building

    private func buildGridItems(from days: [Date]) -> [Date?] {
        guard let first = days.first else { return [] }
        let cal     = Calendar.current
        let weekday = cal.component(.weekday, from: first) - 1  // 0 = Sunday
        var items: [Date?] = Array(repeating: nil, count: weekday)
        items += days.map { Optional($0) }
        while items.count % 7 != 0 { items.append(nil) }
        return items
    }

    // MARK: - Color

    static func heatColor(count: Int, total: Int) -> UIColor {
        guard total > 0, count > 0 else {
            return UIColor(red: 0.91, green: 0.91, blue: 0.93, alpha: 1)
        }
        let t  = CGFloat(count) / CGFloat(total)
        // Light mint → deep green
        let r  = 0.78 * (1 - t) + 0.05 * t
        let g  = 0.96 * (1 - t) + 0.52 * t
        let b  = 0.78 * (1 - t) + 0.20 * t
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - UICollectionView

extension CalendarHeatMapView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        gridItems.count
    }

    func collectionView(_ cv: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: DayCell.id,
                                          for: indexPath) as! DayCell
        if let date = gridItems[indexPath.item] {
            let cal   = Calendar.current
            let day   = cal.component(.day, from: date)
            let count = heat[date] ?? 0
            cell.configure(day: day, count: count, total: totalParticipants)
        } else {
            cell.configureEmpty()
        }
        return cell
    }

    func collectionView(_ cv: UICollectionView,
                        layout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let s = cellSide()
        return CGSize(width: s, height: s)
    }
}

// MARK: - DayCell

private class DayCell: UICollectionViewCell {

    static let id = "DayCell"

    private let circleView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let dayLabel: UILabel = {
        let l = UILabel()
        l.font          = UIFont.systemFont(ofSize: 12, weight: .semibold)
        l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.7
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(circleView)
        circleView.addSubview(dayLabel)
        NSLayoutConstraint.activate([
            circleView.topAnchor.constraint(equalTo: contentView.topAnchor),
            circleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            circleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            circleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            dayLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: circleView.centerYAnchor),
            dayLabel.leadingAnchor.constraint(equalTo: circleView.leadingAnchor, constant: 2),
            dayLabel.trailingAnchor.constraint(equalTo: circleView.trailingAnchor, constant: -2),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        circleView.layer.cornerRadius = circleView.bounds.width / 2
    }

    func configure(day: Int, count: Int, total: Int) {
        dayLabel.isHidden           = false
        dayLabel.text               = "\(day)"
        circleView.backgroundColor  = CalendarHeatMapView.heatColor(count: count, total: total)
        // Dark text for light cells, white for dark.
        let ratio = total > 0 ? CGFloat(count) / CGFloat(total) : 0
        dayLabel.textColor = ratio > 0.55
            ? .white
            : UIColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1)
    }

    func configureEmpty() {
        dayLabel.isHidden          = true
        circleView.backgroundColor = .clear
    }
}
