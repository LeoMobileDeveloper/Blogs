import Foundation
import UIKit

public class RandomColorView : UIView{
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.random()
        let tap = UITapGestureRecognizer(target: self, action: #selector(RandomColorView.handleTap(tap:)));
        addGestureRecognizer(tap)
    }
    func handleTap(tap:UITapGestureRecognizer){
        backgroundColor = UIColor.random()
    }
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
