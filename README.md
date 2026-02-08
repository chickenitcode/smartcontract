# Thực hành `smartcontract` thông qua ngôn ngữ `Solidity` sử dụng framework `Hardhat`

Dự án này giúp các bạn luyện tập cú pháp, tư duy và logic khi thiết kế `smartcontract` thông qua framework đình đám một thời trong cộng đồng web3, đồng thời làm quen với ngôn ngữ mới `Solidity`.


## Tổng quan dự án
- Dự án giúp các bạn luyện tập, tiếp cận thông qua các bài toán kinh điển trong giới lập trình web3 
- Các bài tập được build trên chain Ethereum testnet
- Link nhận faucet testnet cho bạn nào cần: https://cloud.google.com/application/web3/faucet

## Cách build `hardhat`

### Running Tests

To run all the tests in the project, execute the following command:

```shell
npx hardhat test
```

You can also selectively run the Solidity or `node:test` tests:

```shell
npx hardhat test solidity
npx hardhat test nodejs
```

### Make a deployment to Sepolia

This project includes an example Ignition module to deploy the contract. You can deploy this module to a locally simulated chain or to Sepolia.

To run the deployment to a local chain:

```shell
npx hardhat ignition deploy ignition/modules/Counter.ts
```

To run the deployment to Sepolia, you need an account with funds to send the transaction. The provided Hardhat configuration includes a Configuration Variable called `SEPOLIA_PRIVATE_KEY`, which you can use to set the private key of the account you want to use.

You can set the `SEPOLIA_PRIVATE_KEY` variable using the `hardhat-keystore` plugin or by setting it as an environment variable.

To set the `SEPOLIA_PRIVATE_KEY` config variable using `hardhat-keystore`:

```shell
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
```

After setting the variable, you can run the deployment with the Sepolia network:

```shell
npx hardhat ignition deploy --network sepolia ignition/modules/Counter.ts
```
## Đề bài

### 1. VOTING DAPP - Hệ thống bầu chọn Ban quản trị chung cư
- Ngữ cảnh: Một tòa chung cư cần bầu ra Trưởng Ban Quản Trị. Để đảm bảo minh bạch, mỗi căn hộ (đại diện bằng một địa chỉ ví) chỉ có 1 phiếu bầu.

- Yêu cầu chi tiết:

Phân quyền: Chỉ Smart Contract Owner (Ban quản lý) mới được quyền addCandidate (thêm ứng cử viên).

Trạng thái: Một biến bool votingStatus để đóng/mở cổng bình chọn.

Logic: Tạo một struct Candidate gồm: name, voteCount. Người dân gọi hàm vote(uint candidateId).

Ràng buộc: Nếu ví đã vote rồi hoặc thời gian bình chọn đã kết thúc, giao dịch phải bị hủy (revert).

- Mục tiêu Hardhat: Viết test kiểm tra xem một ví cố tình vote 2 lần có bị hệ thống chặn lại hay không.

### 2. MINT TOKEN DAPP - Hệ thống "Điểm thưởng nội bộ"
- Ngữ cảnh: Một chuỗi quán cafe muốn phát hành token COFFEE. Khách hàng nhận được 10 COFFEE cho mỗi cốc cà phê họ mua. Token này có thể dùng để đổi lấy bánh ngọt hoặc giảm giá.

- Yêu cầu chi tiết:

Cơ chế Mint: Chỉ ví của "Máy tính tiền" (được phân quyền MINTER_ROLE) mới được phép tạo token cho khách.

Cơ chế Burn: Khi khách đổi bánh, token COFFEE của khách phải bị xóa bỏ (burn) khỏi tổng cung.

Giới hạn: Tổng cung tối đa (Capped) là 1,000,000 COFFEE để tránh lạm phát.

- Mục tiêu Hardhat: Viết script deploy lên mạng Localhost và thử dùng ví A chuyển 50 token cho ví B.

### 3. ESCROW - Quỹ bảo mật
- Ngữ cảnh: An bán Laptop cho Bình giá 0.5 ETH. Hai người không tin nhau nên dùng Smart Contract làm trung gian.

- Yêu cầu chi tiết:

Bên tham gia: Buyer (Bình), Seller (An), và Arbiter (Người phân xử - có thể là sàn giao dịch).

Quy trình: 1. Bình nạp 0.5 ETH vào hợp đồng. 2. An thấy tiền đã khóa nên gửi máy. 3. Bình nhận máy, bấm confirmReceipt() -> Tiền chuyển về ví An.

Xử lý tranh chấp: Nếu máy hỏng, Arbiter có quyền gọi hàm refund() để trả tiền lại cho Bình.

- Mục tiêu Hardhat: Viết test giả lập tình huống Arbiter can thiệp để hoàn tiền khi người mua khiếu nại.

### 4. DECENTRALIZED CROWDFUNDING - Gọi vốn cộng đồng
- Ngữ cảnh: Một nhóm tình nguyện viên muốn gây quỹ 10 ETH trong 7 ngày để giúp đỡ vùng lũ lụt.

- Yêu cầu chi tiết:

Cấu trúc: Mỗi chiến dịch có targetAmount, deadline, và currentAmount.

An toàn: Nếu hết 7 ngày mà chỉ quyên góp được 8 ETH, hợp đồng tự động mở chức năng withdrawRefund cho tất cả mọi người đã đóng góp.

Rút tiền: Chỉ khi đạt đủ 10 ETH, người tạo quỹ mới được rút tiền ra (claim).

- Mục tiêu Hardhat: Sử dụng helpers.time.increase của Hardhat để "nhảy thời gian" về tương lai nhằm kiểm tra logic hết hạn.

### 5. NFT WHITELIST SALE (Advanced) - The Merkle-IPFS Hybrid
- Ngữ cảnh thực tế:
Dự án NFT "Cyber-Samurai" phát hành 10,000 vật phẩm. Ảnh và Metadata được lưu trên IPFS. Họ có danh sách 5,000 ví được ưu tiên mua trước (Whitelist).

- Yêu cầu kỹ thuật nâng cao:
+  Merkle Tree Verification:

Off-chain: Viết một script (JavaScript) sử dụng merkletreejs để băm (hash) danh sách 5,000 ví và tạo ra một Merkle Root.

On-chain: Contract chỉ lưu duy nhất biến bytes32 public merkleRoot.

Logic: Khi người dùng Mint, họ phải gửi kèm một bytes32[] calldata proof. Contract dùng proof này cùng với msg.sender để tính toán xem có khớp với merkleRoot hay không.

+ IPFS Integration:

Sử dụng Pinata hoặc NFT.storage để upload thư mục ảnh và metadata.

Contract sử dụng chuẩn ERC721Enumerable và lưu baseURI dẫn đến CID của IPFS (ví dụ: ipfs://Qm.../).

+ Provable Fairness: Sử dụng cơ chế "Delayed Reveal". Lúc đầu tokenURI chỉ trỏ về một file JSON "Hidden" chung. Sau khi bán hết, Owner mới update baseURI thật.

- Thử thách Hardhat:
Viết test giả lập: Tạo 2 ví (1 ví có trong whitelist, 1 ví không). Ví hợp lệ phải tạo được proof và mint thành công, ví không hợp lệ phải bị revert với lỗi "Invalid Proof".

### 6. STAKING CONTRACT (Advanced) - Multi-reward & timelock vault
- Ngữ cảnh thực tế:
Một giao thức DeFi cho phép người dùng Stake token LP (Liquidity Provider). 
Phần thưởng nhận được không chỉ là token dự án (REWARD) mà còn có thể là một phần phí giao dịch của nền tảng.
- Yêu cầu kỹ thuật nâng cao:
+ Algorithm "Reward Per Token": 
* Thay vì dùng vòng lặp for (gây tốn gas và treo contract), bạn phải sử dụng công thức:
$$\text{Reward Per Token} = \sum \frac{\text{Rewards Distributed}}{\text{Total Staked}}$$
Mỗi khi có người stake, withdraw hoặc getReward, contract phải cập nhật chỉ số này.
+ Timelock & Multiplier:
    Nếu người dùng cam kết khóa token trong 3 tháng, họ nhận được hệ số nhân lãi suất (Multiplier) là $1.5x$
    Nếu rút trước hạn (Early Unstake), họ sẽ bị phạt 10% số gốc.
+ Compound Feature: Cho phép người dùng tự động cộng dồn phần thưởng vào gốc (Auto-compounding) để tăng lãi kép.
- Thử thách Hardhat Time Travel Testing: Dùng ethers.provider.send("evm_mine") để đào các block trống và kiểm tra xem biến rewardPerTokenStored có tăng chính xác theo thời gian hay không. Math Precision: Kiểm tra sai số làm tròn (Rounding errors). Vì Solidity không có số thập phân, bạn phải xử lý với độ chính xác 18 chữ số ($10^{18}$).